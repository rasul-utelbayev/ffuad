# FFUAD Server

FFUAD is a bilingual, multi-profile file server for Termux and Linux. The complete application is implemented in one Bash script and provides a responsive browser interface for managing files through local, Cloudflare, and Tor links.

## English

### Overview

FFUAD lets you create independent named server profiles. Each profile has its own storage folder, language preference, optional administrator-access password, and isolated session. Links are generated only after you select the server profile you want to expose.

When someone opens a server link, the website first offers two access modes:

- **Log in as administrator** for full file and folder management
- **Continue as guest** without a username or password for read-only browsing and downloads

A selected profile can provide:

- A local network address
- A localhost address
- A temporary Cloudflare Quick Tunnel address
- A session-specific Tor onion address

Different profiles can run at the same time in separate Termux tabs or terminal sessions. Each running profile receives its own port, runtime directory, authentication cookie, Cloudflare process, and Tor process.

### Features

- Multiple named server profiles
- Optional administrator-access password for each server
- Passwordless guest access without usernames or accounts
- Server-enforced guest read-only permissions
- Separate storage folder for every profile
- Automatic storage-folder naming from the server name
- Optional custom storage location
- English and Greek terminal menus
- English and Greek browser interface
- Dark and light themes
- File and folder browsing
- Multiple-file uploads with progress
- File downloads
- Folder downloads as ZIP archives
- Folder creation
- File and folder moving
- File and folder renaming
- Individual and bulk deletion
- Confirmation before every modifying or destructive action
- Recursive search
- Category filters for folders, documents, images, videos, audio, archives, code, applications, and other files
- File details including name, path, category, size, MIME type, creation date, modification date, and SHA-256 checksum
- Collision-safe upload names
- Signed administrator and guest sessions for each profile
- Guest access limited to browsing, search, details, and downloads
- CSRF protection
- Storage-root containment and traversal protection
- Automatic dependency installation on Termux
- Independent Cloudflare and Tor sessions
- Automatic cleanup when a server session stops

### Requirements

FFUAD installs the required packages through its installer. On Termux, storage access should be enabled before selecting a shared-storage directory:

```bash
termux-setup-storage
```

### Installation on Termux

```bash
pkg update -y
pkg install -y git unzip
unzip ffuad-main-guest-access.zip
cd ffuad-main
chmod +x ffuad.sh
./ffuad.sh --install
./ffuad.sh
```

### Installation on Linux

```bash
unzip ffuad-main-guest-access.zip
cd ffuad-main
chmod +x ffuad.sh
./ffuad.sh --install
./ffuad.sh
```

### Normal use

Open the interactive manager:

```bash
./ffuad.sh
```

Choose a server and start it:

```bash
./ffuad.sh --start
```

Start a known profile directly:

```bash
./ffuad.sh --start SERVER_ID
```

Run the direct-start command in separate Termux tabs to keep different server profiles active simultaneously.

### Profile management

```bash
./ffuad.sh --create
./ffuad.sh --edit
./ffuad.sh --delete
./ffuad.sh --list-servers
./ffuad.sh --show-password
```

### Website access modes

Every generated Local, Cloudflare, and Tor link opens an access-selection page.

**Administrator access** provides:

- Uploads
- Folder creation
- Moving and renaming
- Individual and bulk deletion
- All guest capabilities

**Guest access** requires no username or password and provides only:

- Folder browsing
- Recursive search and category filters
- Entry details and SHA-256 viewing
- File downloads
- Folder downloads as ZIP archives

Guest restrictions are enforced by the Bash CGI backend, not only by hiding buttons in the browser. Direct requests to upload, create, move, rename, or delete are rejected for guest sessions.

The administrator password protects local profile creation, editing, and deletion. A profile password is separate and optional and protects administrator access. Guest access never requires a username or password. When a profile has no administrator password, anyone with an active link can also choose administrator access, so public profiles should normally use a strong password.

### Link behavior

FFUAD does not create public links when the manager first opens. It waits until a server profile is selected.

After selection, the chosen profile starts on an available port and FFUAD attempts to generate all supported links. Cloudflare Quick Tunnel and Tor addresses are temporary for that running session and may change the next time the profile starts.

Stop the active session with:

```text
Ctrl+C
```

Stopping one terminal session does not stop profiles running in other terminal sessions.

### Data locations

Default configuration directory:

```text
~/.config/ffuad
```

Default profile storage directory:

```text
~/FFUAD-Servers
```

Custom locations can be assigned when creating or editing a profile.

### Security notes

- Use a strong administrator password before sharing a public link.
- Share guest access when users only need to view or download files.
- Treat a passwordless profile as publicly accessible to anyone with its active URL.
- Keep Termux and installed packages updated.
- Do not expose folders containing credentials, private keys, recovery codes, or unrelated application data.
- Review [SECURITY.md](SECURITY.md) before reporting a vulnerability.

### License

This project is distributed under the MIT License. See [LICENSE](LICENSE).

---

## Ελληνικά

### Επισκόπηση

Το FFUAD είναι ένας δίγλωσσος διακομιστής αρχείων πολλαπλών προφίλ για Termux και Linux. Ολόκληρη η εφαρμογή βρίσκεται σε ένα αρχείο Bash και παρέχει προσαρμοζόμενο περιβάλλον περιήγησης για διαχείριση αρχείων μέσω τοπικών συνδέσμων, Cloudflare και Tor.

Μπορείς να δημιουργήσεις ανεξάρτητα προφίλ διακομιστών με διαφορετικά ονόματα. Κάθε προφίλ έχει δικό του φάκελο αποθήκευσης, προτίμηση γλώσσας, προαιρετικό κωδικό πρόσβασης διαχειριστή και ξεχωριστή συνεδρία. Οι σύνδεσμοι δημιουργούνται μόνο αφού επιλέξεις τον διακομιστή που θέλεις να ανοίξεις.

Όταν κάποιος ανοίγει έναν σύνδεσμο διακομιστή, η ιστοσελίδα εμφανίζει πρώτα δύο τρόπους πρόσβασης:

- **Σύνδεση ως διαχειριστής** για πλήρη διαχείριση αρχείων και φακέλων
- **Συνέχεια ως επισκέπτης** χωρίς όνομα χρήστη ή κωδικό, μόνο για προβολή και λήψη

Ένα επιλεγμένο προφίλ μπορεί να παρέχει:

- Διεύθυνση τοπικού δικτύου
- Διεύθυνση localhost
- Προσωρινή διεύθυνση Cloudflare Quick Tunnel
- Διεύθυνση Tor onion για τη συγκεκριμένη συνεδρία

Διαφορετικά προφίλ μπορούν να λειτουργούν ταυτόχρονα σε ξεχωριστές καρτέλες Termux ή συνεδρίες τερματικού. Κάθε ενεργό προφίλ χρησιμοποιεί δική του θύρα, φάκελο εκτέλεσης, cookie σύνδεσης, διεργασία Cloudflare και διεργασία Tor.

### Δυνατότητες

- Πολλαπλά προφίλ διακομιστών με διαφορετικά ονόματα
- Προαιρετικός κωδικός πρόσβασης διαχειριστή για κάθε διακομιστή
- Πρόσβαση επισκέπτη χωρίς όνομα χρήστη ή λογαριασμό
- Περιορισμοί επισκέπτη που επιβάλλονται από τον διακομιστή
- Ξεχωριστός φάκελος αποθήκευσης για κάθε προφίλ
- Αυτόματη ονομασία φακέλου από το όνομα του διακομιστή
- Προαιρετική προσαρμοσμένη τοποθεσία αποθήκευσης
- Μενού τερματικού στα Αγγλικά και στα Ελληνικά
- Περιβάλλον ιστοσελίδας στα Αγγλικά και στα Ελληνικά
- Σκούρο και φωτεινό θέμα
- Περιήγηση σε αρχεία και φακέλους
- Μεταφόρτωση πολλών αρχείων με ένδειξη προόδου
- Λήψη αρχείων
- Λήψη φακέλων ως αρχεία ZIP
- Δημιουργία φακέλων
- Μετακίνηση αρχείων και φακέλων
- Μετονομασία αρχείων και φακέλων
- Μεμονωμένη και μαζική διαγραφή
- Επιβεβαίωση πριν από κάθε αλλαγή ή διαγραφή
- Αναδρομική αναζήτηση
- Φίλτρα κατηγοριών για φακέλους, έγγραφα, εικόνες, βίντεο, ήχο, συμπιεσμένα αρχεία, κώδικα, εφαρμογές και άλλα αρχεία
- Λεπτομέρειες αρχείων όπως όνομα, διαδρομή, κατηγορία, μέγεθος, τύπος MIME, ημερομηνία δημιουργίας, ημερομηνία τροποποίησης και SHA-256
- Ασφαλή αυτόματα ονόματα όταν υπάρχει αρχείο με το ίδιο όνομα
- Υπογεγραμμένες συνεδρίες διαχειριστή και επισκέπτη για κάθε προφίλ
- Πρόσβαση επισκέπτη μόνο για περιήγηση, αναζήτηση, λεπτομέρειες και λήψεις
- Προστασία CSRF
- Περιορισμός ενεργειών μέσα στον επιλεγμένο φάκελο αποθήκευσης
- Αυτόματη εγκατάσταση εξαρτήσεων στο Termux
- Ανεξάρτητες συνεδρίες Cloudflare και Tor
- Αυτόματος τερματισμός διεργασιών όταν κλείνει η συνεδρία

### Απαιτήσεις

Το FFUAD εγκαθιστά τα απαραίτητα πακέτα μέσω της επιλογής εγκατάστασης. Στο Termux πρέπει να ενεργοποιηθεί η πρόσβαση στον κοινόχρηστο χώρο πριν επιλέξεις φάκελο της συσκευής:

```bash
termux-setup-storage
```

### Εγκατάσταση στο Termux

```bash
pkg update -y
pkg install -y git unzip
unzip ffuad-main-guest-access.zip
cd ffuad-main
chmod +x ffuad.sh
./ffuad.sh --install
./ffuad.sh
```

### Εγκατάσταση στο Linux

```bash
unzip ffuad-main-guest-access.zip
cd ffuad-main
chmod +x ffuad.sh
./ffuad.sh --install
./ffuad.sh
```

### Κανονική χρήση

Άνοιγμα του διαδραστικού διαχειριστή:

```bash
./ffuad.sh
```

Επιλογή και εκκίνηση διακομιστή:

```bash
./ffuad.sh --start
```

Άμεση εκκίνηση γνωστού προφίλ:

```bash
./ffuad.sh --start SERVER_ID
```

Μπορείς να εκτελέσεις την άμεση εντολή σε διαφορετικές καρτέλες Termux ώστε να παραμένουν ενεργοί διαφορετικοί διακομιστές ταυτόχρονα.

### Διαχείριση προφίλ

```bash
./ffuad.sh --create
./ffuad.sh --edit
./ffuad.sh --delete
./ffuad.sh --list-servers
./ffuad.sh --show-password
```

### Τρόποι πρόσβασης στην ιστοσελίδα

Κάθε σύνδεσμος Local, Cloudflare και Tor ανοίγει πρώτα σελίδα επιλογής πρόσβασης.

Η **πρόσβαση διαχειριστή** παρέχει:

- Μεταφορτώσεις
- Δημιουργία φακέλων
- Μετακίνηση και μετονομασία
- Μεμονωμένη και μαζική διαγραφή
- Όλες τις δυνατότητες επισκέπτη

Η **πρόσβαση επισκέπτη** δεν απαιτεί όνομα χρήστη ή κωδικό και παρέχει μόνο:

- Περιήγηση σε φακέλους
- Αναδρομική αναζήτηση και φίλτρα κατηγοριών
- Προβολή λεπτομερειών και SHA-256
- Λήψη αρχείων
- Λήψη φακέλων ως ZIP

Οι περιορισμοί επισκέπτη επιβάλλονται από το Bash CGI backend και όχι μόνο με απόκρυψη κουμπιών. Άμεσες προσπάθειες για μεταφόρτωση, δημιουργία, μετακίνηση, μετονομασία ή διαγραφή απορρίπτονται για συνεδρίες επισκέπτη.

Ο κωδικός διαχειριστή προστατεύει την τοπική δημιουργία, επεξεργασία και διαγραφή προφίλ. Ο κωδικός ενός προφίλ είναι ξεχωριστός, προαιρετικός και προστατεύει την πρόσβαση διαχειριστή στην ιστοσελίδα. Η πρόσβαση επισκέπτη δεν απαιτεί όνομα χρήστη ή κωδικό. Αν ένα προφίλ δεν έχει κωδικό διαχειριστή, οποιοσδήποτε έχει ενεργό σύνδεσμο μπορεί να επιλέξει πλήρη πρόσβαση διαχειριστή, επομένως τα δημόσια προφίλ πρέπει συνήθως να έχουν ισχυρό κωδικό.

### Λειτουργία συνδέσμων

Το FFUAD δεν δημιουργεί δημόσιους συνδέσμους όταν ανοίγει ο διαχειριστής. Περιμένει πρώτα να επιλέξεις συγκεκριμένο προφίλ.

Μετά την επιλογή, το προφίλ ξεκινά σε διαθέσιμη θύρα και το FFUAD προσπαθεί να δημιουργήσει όλους τους υποστηριζόμενους συνδέσμους. Οι διευθύνσεις Cloudflare Quick Tunnel και Tor είναι προσωρινές για την ενεργή συνεδρία και μπορούν να αλλάξουν στην επόμενη εκκίνηση.

Σταμάτημα της ενεργής συνεδρίας:

```text
Ctrl+C
```

Το σταμάτημα μίας συνεδρίας τερματικού δεν επηρεάζει προφίλ που λειτουργούν σε άλλες συνεδρίες.

### Τοποθεσίες δεδομένων

Προεπιλεγμένος φάκελος ρυθμίσεων:

```text
~/.config/ffuad
```

Προεπιλεγμένος φάκελος αποθήκευσης προφίλ:

```text
~/FFUAD-Servers
```

Μπορείς να επιλέξεις προσαρμοσμένη τοποθεσία κατά τη δημιουργία ή την επεξεργασία ενός προφίλ.

### Σημειώσεις ασφαλείας

- Χρησιμοποίησε ισχυρό κωδικό διαχειριστή πριν κοινοποιήσεις δημόσιο σύνδεσμο.
- Χρησιμοποίησε την πρόσβαση επισκέπτη όταν οι χρήστες χρειάζονται μόνο προβολή ή λήψη αρχείων.
- Θεώρησε ένα προφίλ χωρίς κωδικό δημόσια προσβάσιμο σε οποιονδήποτε έχει την ενεργή διεύθυνσή του.
- Διατήρησε ενημερωμένα το Termux και τα εγκατεστημένα πακέτα.
- Μην εκθέτεις φακέλους που περιέχουν κωδικούς, ιδιωτικά κλειδιά, κωδικούς ανάκτησης ή δεδομένα άλλων εφαρμογών.
- Διάβασε το [SECURITY.md](SECURITY.md) πριν αναφέρεις ευπάθεια.

### Άδεια χρήσης

Το έργο διατίθεται με την άδεια MIT. Δες το [LICENSE](LICENSE).
