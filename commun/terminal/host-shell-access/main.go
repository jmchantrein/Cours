// host-shell-access — relie une page de cours, et son terminal, au vrai shell de l'étudiant.
//
// Usage : host-shell-access local, puis coller dans la page (Terminal → Mon shell) l'adresse affichée.
// Un clic sur « Exécuter » dans la page lance la commande dans ce shell, avec les droits de l'utilisateur.
//
// Réécriture en Go de l'ancien script Python du dépôt jmchantrein/site, même protocole et mêmes protections :
//   - écoute sur 127.0.0.1 seulement, port tiré par le système ;
//   - adresse à jeton aléatoire (32 octets), comparé en temps constant : 401 sinon ;
//   - origine de la page dans une liste fixe (plus --origin) : 403 sinon ;
//   - une seule connexion acceptée : le processus s'arrête avec elle, refusée ou non (jeton à usage unique).
//
// Protocole, en trames texte JSON : la page envoie {"type":"input","data":…} et {"type":"resize","cols","rows"} ;
// host-shell-access renvoie {"type":"output","data":…}.
package main

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/coder/websocket"
	"github.com/creack/pty"
)

// Origines admises : le site des cours, et les pages servies en local pour les essais (python3 -m http.server).
var originesParDefaut = []string{
	"https://jmchantrein.github.io",
	"http://localhost:8000",
	"http://127.0.0.1:8000",
}

const tailleMaxMessage = 1 << 20

type message struct {
	Type string `json:"type"`
	Data string `json:"data,omitempty"`
	Cols int    `json:"cols,omitempty"`
	Rows int    `json:"rows,omitempty"`
}

type origines []string

func (o *origines) String() string     { return strings.Join(*o, ",") }
func (o *origines) Set(v string) error { *o = append(*o, v); return nil }

func usage() {
	fmt.Fprintf(os.Stderr, `Relie la page du cours à votre shell (ou à une session SSH).

Usage :
  host-shell-access [options] local [--shell CHEMIN]
  host-shell-access [options] ssh [options de ssh] utilisateur@hôte

Options :
`)
	flag.PrintDefaults()
}

func main() {
	var extra origines
	port := flag.Int("port", 0, "port de bouclage (par défaut : tiré au hasard)")
	flag.Var(&extra, "origin", "origine de page supplémentaire autorisée (répétable)")
	cert := flag.String("cert", "", "certificat TLS, pour wss://")
	cle := flag.String("key", "", "clé privée TLS, pour wss://")
	flag.Usage = usage
	flag.Parse()
	if (*cert == "") != (*cle == "") {
		sortir("--cert et --key vont ensemble")
	}
	commande, cible := commandeDe(flag.Args())

	jeton := aleatoire()
	ecoute, err := net.Listen("tcp4", fmt.Sprintf("127.0.0.1:%d", *port))
	if err != nil {
		sortir(err.Error())
	}
	schema := "ws"
	if *cert != "" {
		schema = "wss"
	}
	fmt.Printf("Adresse à coller dans la page :\n%s://localhost:%d/?token=%s\n", schema, ecoute.Addr().(*net.TCPAddr).Port, jeton)
	fmt.Fprintf(os.Stderr, "Un clic sur « Exécuter » dans la page lancera la commande dans %s, avec vos droits.\n"+
		"Adresse valable pour une connexion : fermer la page arrête host-shell-access.\n", cible)

	admises := map[string]bool{}
	for _, o := range append(originesParDefaut, extra...) {
		admises[o] = true
	}
	// Une seule connexion est acceptée ; les suivantes restent sans réponse, puis le processus s'arrête.
	unique := &uneConnexion{Listener: ecoute, fin: make(chan struct{})}
	serveur := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer unique.terminer()
		recu := r.URL.Query().Get("token")
		if r.Method != http.MethodGet || subtle.ConstantTimeCompare([]byte(recu), []byte(jeton)) != 1 {
			refuser(w, http.StatusUnauthorized)
			return
		}
		if !admises[r.Header.Get("Origin")] {
			refuser(w, http.StatusForbidden)
			return
		}
		// L'origine est déjà vérifiée, exactement (schéma, hôte, port) : la bibliothèque n'a pas à le refaire.
		ws, err := websocket.Accept(w, r, &websocket.AcceptOptions{InsecureSkipVerify: true})
		if err != nil {
			return
		}
		ws.SetReadLimit(tailleMaxMessage)
		session(r.Context(), ws, commande)
		fmt.Fprintln(os.Stderr, "Session terminée.")
	})}
	// Une connexion qui se ferme sans requête complète arrête aussi host-shell-access.
	serveur.ReadHeaderTimeout = 10 * time.Second
	serveur.ConnState = func(_ net.Conn, etat http.ConnState) {
		if etat == http.StateClosed {
			unique.terminer()
		}
	}
	go func() {
		if *cert != "" {
			_ = serveur.ServeTLS(unique, *cert, *cle)
		} else {
			_ = serveur.Serve(unique)
		}
	}()
	<-unique.fin
	// La réponse d'un refus part avant l'arrêt.
	ctx, annuler := context.WithTimeout(context.Background(), 2*time.Second)
	defer annuler()
	_ = serveur.Shutdown(ctx)
}

// commandeDe donne le programme à lancer dans le pseudo-terminal, et ce qu'il est, pour le message d'accueil.
func commandeDe(args []string) ([]string, string) {
	if len(args) == 0 {
		usage()
		os.Exit(2)
	}
	switch args[0] {
	case "local":
		options := flag.NewFlagSet("local", flag.ExitOnError)
		shell := os.Getenv("SHELL")
		if shell == "" {
			shell = "/bin/sh"
		}
		options.StringVar(&shell, "shell", shell, "shell à lancer")
		_ = options.Parse(args[1:])
		return []string{shell, "-l"}, "ce shell"
	case "ssh":
		// Clés, agent, ~/.ssh/config et vérification de l'hôte restent l'affaire du client ssh du poste.
		if len(args) < 2 {
			sortir("indiquez la destination SSH : host-shell-access ssh utilisateur@hôte")
		}
		return append([]string{"ssh", "-tt"}, args[1:]...), "la session SSH"
	}
	usage()
	os.Exit(2)
	return nil, ""
}

// session relie la connexion WebSocket et le pseudo-terminal du shell, jusqu'à ce que l'un des deux se ferme.
func session(ctx context.Context, ws *websocket.Conn, commande []string) {
	ctx, annuler := context.WithCancel(ctx)
	defer annuler()
	cmd := exec.Command(commande[0], commande[1:]...)
	// Un pseudo-terminal donne au shell ce qu'il attend d'un terminal : invite, contrôle des tâches, couleurs.
	terminal, err := pty.StartWithSize(cmd, &pty.Winsize{Cols: 100, Rows: 32})
	if err != nil {
		_ = ws.Close(websocket.StatusInternalError, "shell impossible à lancer")
		fmt.Fprintln(os.Stderr, "Shell impossible à lancer :", err)
		return
	}
	defer func() {
		_ = terminal.Close()
		if cmd.Process != nil {
			_ = cmd.Process.Signal(sighup)
		}
		_ = cmd.Wait()
	}()

	var envoi sync.Mutex
	go func() { // shell → page
		defer annuler()
		tampon, reste := make([]byte, 32768), []byte(nil)
		for {
			n, err := terminal.Read(tampon)
			if n > 0 {
				// Un caractère UTF-8 coupé entre deux lectures attend la suite au lieu d'être remplacé.
				donnees := append(reste, tampon[:n]...)
				coupe := finUTF8(donnees)
				reste = append([]byte(nil), donnees[coupe:]...)
				sortie, _ := json.Marshal(message{Type: "output", Data: strings.ToValidUTF8(string(donnees[:coupe]), "\uFFFD")})
				envoi.Lock()
				err := ws.Write(ctx, websocket.MessageText, sortie)
				envoi.Unlock()
				if err != nil {
					return
				}
			}
			if err != nil {
				_ = ws.Close(websocket.StatusNormalClosure, "shell terminé")
				return
			}
		}
	}()
	for { // page → shell
		genre, donnees, err := ws.Read(ctx)
		if err != nil {
			return
		}
		var m message
		if genre != websocket.MessageText || json.Unmarshal(donnees, &m) != nil {
			continue
		}
		switch m.Type {
		case "input":
			if _, err := io.WriteString(terminal, m.Data); err != nil {
				return
			}
		case "resize":
			_ = pty.Setsize(terminal, &pty.Winsize{Cols: uint16(borne(m.Cols, 20, 500)), Rows: uint16(borne(m.Rows, 5, 200))})
		}
	}
}

// finUTF8 donne la longueur du plus long préfixe de b qui ne s'arrête pas au milieu d'un caractère UTF-8.
func finUTF8(b []byte) int {
	for i := len(b) - 1; i >= 0 && i >= len(b)-utf8.UTFMax; i-- {
		if utf8.RuneStart(b[i]) {
			if utf8.FullRune(b[i:]) {
				return len(b)
			}
			return i
		}
	}
	return len(b)
}

func borne(v, min, max int) int {
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}

func refuser(w http.ResponseWriter, statut int) {
	fmt.Fprintf(os.Stderr, "Connexion refusée : %d %s\n", statut, http.StatusText(statut))
	w.Header().Set("Connection", "close")
	w.WriteHeader(statut)
}

func aleatoire() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		sortir(err.Error())
	}
	return base64.RawURLEncoding.EncodeToString(b)
}

func sortir(texte string) {
	fmt.Fprintln(os.Stderr, "host-shell-access :", texte)
	os.Exit(1)
}

// uneConnexion est un net.Listener qui ne rend qu'une connexion : les suivantes restent en attente, sans
// réponse, jusqu'à l'arrêt du processus, qui suit la fin de la première (terminer).
type uneConnexion struct {
	net.Listener
	prise  bool
	fin    chan struct{}
	finUne sync.Once
	verrou sync.Mutex
}

func (u *uneConnexion) Accept() (net.Conn, error) {
	u.verrou.Lock()
	if u.prise {
		u.verrou.Unlock()
		<-u.fin
		return nil, errors.New("host-shell-access arrêté")
	}
	u.prise = true
	u.verrou.Unlock()
	return u.Listener.Accept()
}

func (u *uneConnexion) terminer() { u.finUne.Do(func() { close(u.fin) }) }
