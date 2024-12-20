# soko-friend-system-pawn
 Basic MySQL friend system for SA:MP 0.3.7-R2 server<br>
Created at: 20.12.2024.

Developed by Dragan Avdic (Dragi)<br>
Credits:<br>
- BlueG

> [!IMPORTANT]
>Pored standardnih threaded asinhronih upita, odlucio sam se da ubacim 2 unthreaded query-a i ni pod tackom razno NE PREPORUCUJEM cackanje toga jer moze doci do obaranja memorije sistema!

Uradjeno je olaksano i bez finti(trikova) DONEKLE zbog pocetnika iako ne preporucujem svezim pocetnicima ovaj rad zbog slozenijih SQL upita i logike.

Unesete komandu '/prijatelji' i tu vam je celokupan basic sistem. Dodao sam da mozete poslati SMS direktno prijatelju, ali to je u fazi razvoja, odnosno vi ubacite vas gde sam tacno oznacio. Sistem mozete uvek unaprediti i dodati 1000 opcija...

*Useful Functions aka 'uf.inc' sam ubacio jer su mi trebale 2-3 funkcije, mogao sam ih direktno implementirati ali zbog daljeg razvoja sam implementirao biblioteku. Koriscenje funkcije su prepravljene od strane mene, originale su bile ubagovane i nece vam raditi ako ne skinete ovaj moj 'uf.inc'

Ne bi trebalo da bude bugova, sistem je testiran. Ukoliko ipak pronadjete, zamolicu da mi prijavite. Veliko hvala.

Plugini:<br>
- MySQL R41-4,
- Bcrypt 0.4.1,
- sscanf 2.13.8
- Pawn.CMD 3.4.0

Compiler: Pawn compiler 3.10.10