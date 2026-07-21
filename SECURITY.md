# Security Policy

## English

### Supported code

Security fixes are applied to the latest code in the default branch. Older archives, forks, and modified copies may not receive security updates.

### Reporting a vulnerability

Please do not publish a security vulnerability in a public issue, discussion, pull request, screenshot, or social-media post.

Use one of these private methods:

1. Open a private GitHub Security Advisory for the repository, when that option is available.
2. Contact the repository maintainer privately through a contact method listed on the maintainer's GitHub profile or repository page.

Include:

- A clear description of the issue
- The affected command, page, route, or feature
- Reproduction steps
- The expected and actual behavior
- The operating system and environment
- Relevant logs with passwords, tokens, onion addresses, public tunnel addresses, personal paths, and private filenames removed
- A proposed correction, when available

Please allow the maintainer time to reproduce, correct, and publish the fix before disclosing technical details publicly.

### Security boundaries

FFUAD exposes files selected by the server administrator. Administrators are responsible for:

- Selecting a safe storage directory
- Setting a strong administrator-access password before sharing a public link
- Using guest access for users who only need to browse or download
- Protecting the administrator password
- Keeping Termux, Bash, BusyBox, Cloudflare Tunnel, Tor, and other dependencies updated
- Reviewing files before making them reachable through public links
- Stopping inactive sessions
- Avoiding exposure of credentials, private keys, recovery codes, application databases, and unrelated private data

Cloudflare Quick Tunnel and Tor links should be treated as public network entry points. Guest sessions are read-only and are restricted by server-side route checks. They may browse, search, inspect details, and download, but cannot upload, create folders, move, rename, or delete.

A profile without an administrator password allows anyone with its active address to choose full administrator access. Guest mode does not compensate for a missing administrator password.

### Sensitive information

Never include real passwords, cookies, authentication tokens, private keys, complete configuration directories, active onion addresses, active Cloudflare links, or private user files in a vulnerability report.

---

## Ελληνικά

### Υποστηριζόμενος κώδικας

Οι διορθώσεις ασφαλείας εφαρμόζονται στον πιο πρόσφατο κώδικα του προεπιλεγμένου κλάδου. Παλαιότερα αρχεία, forks και τροποποιημένα αντίγραφα μπορεί να μη λαμβάνουν ενημερώσεις ασφαλείας.

### Αναφορά ευπάθειας

Μη δημοσιεύεις ευπάθεια ασφαλείας σε δημόσιο issue, discussion, pull request, στιγμιότυπο οθόνης ή ανάρτηση σε κοινωνικό δίκτυο.

Χρησιμοποίησε έναν από τους παρακάτω ιδιωτικούς τρόπους:

1. Άνοιξε ιδιωτικό GitHub Security Advisory για το αποθετήριο, όταν είναι διαθέσιμη αυτή η επιλογή.
2. Επικοινώνησε ιδιωτικά με τον συντηρητή μέσω στοιχείου επικοινωνίας που εμφανίζεται στο προφίλ GitHub ή στη σελίδα του αποθετηρίου.

Συμπερίλαβε:

- Καθαρή περιγραφή του προβλήματος
- Την επηρεαζόμενη εντολή, σελίδα, διαδρομή ή λειτουργία
- Βήματα αναπαραγωγής
- Την αναμενόμενη και την πραγματική συμπεριφορά
- Το λειτουργικό σύστημα και το περιβάλλον
- Σχετικά αρχεία καταγραφής χωρίς κωδικούς, tokens, διευθύνσεις onion, δημόσιους συνδέσμους tunnel, προσωπικές διαδρομές και ιδιωτικά ονόματα αρχείων
- Προτεινόμενη διόρθωση, όταν υπάρχει

Δώσε στον συντηρητή χρόνο να αναπαράγει το πρόβλημα, να το διορθώσει και να δημοσιεύσει την ενημέρωση πριν κοινοποιήσεις δημόσια τεχνικές λεπτομέρειες.

### Όρια ασφαλείας

Το FFUAD εκθέτει αρχεία που επιλέγει ο διαχειριστής του διακομιστή. Οι διαχειριστές είναι υπεύθυνοι για:

- Την επιλογή ασφαλούς φακέλου αποθήκευσης
- Τη ρύθμιση ισχυρού κωδικού πρόσβασης διαχειριστή πριν κοινοποιηθεί δημόσιος σύνδεσμος
- Τη χρήση πρόσβασης επισκέπτη για χρήστες που χρειάζονται μόνο περιήγηση ή λήψη
- Την προστασία του κωδικού διαχειριστή
- Τη διατήρηση ενημερωμένων των Termux, Bash, BusyBox, Cloudflare Tunnel, Tor και άλλων εξαρτήσεων
- Τον έλεγχο των αρχείων πριν γίνουν προσβάσιμα μέσω δημόσιων συνδέσμων
- Το σταμάτημα ανενεργών συνεδριών
- Την αποφυγή έκθεσης κωδικών, ιδιωτικών κλειδιών, κωδικών ανάκτησης, βάσεων δεδομένων εφαρμογών και άσχετων προσωπικών δεδομένων

Οι σύνδεσμοι Cloudflare Quick Tunnel και Tor πρέπει να θεωρούνται δημόσια σημεία πρόσβασης δικτύου. Οι συνεδρίες επισκέπτη είναι μόνο για ανάγνωση και περιορίζονται από ελέγχους διαδρομών στο backend. Μπορούν να περιηγούνται, να αναζητούν, να βλέπουν λεπτομέρειες και να κατεβάζουν, αλλά δεν μπορούν να μεταφορτώνουν, να δημιουργούν φακέλους, να μετακινούν, να μετονομάζουν ή να διαγράφουν.

Ένα προφίλ χωρίς κωδικό πρόσβασης διαχειριστή επιτρέπει σε οποιονδήποτε έχει την ενεργή διεύθυνση να επιλέξει πλήρη πρόσβαση διαχειριστή. Η λειτουργία επισκέπτη δεν αντικαθιστά τον κωδικό διαχειριστή.

### Ευαίσθητες πληροφορίες

Μη συμπεριλαμβάνεις πραγματικούς κωδικούς, cookies, tokens πιστοποίησης, ιδιωτικά κλειδιά, ολόκληρους φακέλους ρυθμίσεων, ενεργές διευθύνσεις onion, ενεργούς συνδέσμους Cloudflare ή ιδιωτικά αρχεία χρηστών σε αναφορά ευπάθειας.
