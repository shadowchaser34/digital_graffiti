# Obiective — iTEC: OVERRIDE

Scop: Construirea unei aplicații mobile colaborative de tip AR / graffiti digital, în care afișele-ancoră din locație devin canvas-uri vii, cu desen, stickere, media și sunet sincronizate în timp real. Setul de referință pentru învățare și test este în `docs/project_definition/poze`.

Obiective principale
- Detectarea afișelor-ancoră prin cameră și transformarea lor în canvas-uri interactive.
- Folosirea imaginilor de referință ale afișelor pentru recunoaștere, ancorare și testare a poziționării.
- Implementare canvas vectorial pentru freehand drawing folosind `CustomPainter`.
- Stocare vectorială a traseelor, stickerelor și altor adnotări în Firebase / Firestore.
- Sincronizare în timp real pentru trasee, stickere, imagini și stare de colaborare.
- Plasare, scalare și rotație pentru stickere PNG / GIF și alte media persistente.
- Declanșarea automată a sunetului atașat unui afiș când este scanat de alt utilizator.
- Calculul „teritoriului” sau al deținerii unui afiș în funcție de activitatea echipelor.
- Randarea corectă a conținutului pe afiș indiferent de dimensiunea camerei sau device.
- UI mobil clar, rapid și responsabil, cu toolbar pentru culoare, grosime, stickere, media, undo/redo și stare de echipă.
- Experiență creativă bonus: glitch, haptics, AI tag generator și easter-eggs, doar dacă nu blochează funcționalitatea de bază.

Criterii de acceptare
- Scanarea unui afiș-ancoră deschide același canvas și poziționează corect conținutul pe toate device-urile.
- Traseele și stickerele sunt salvate incremental și apar instant pe alte dispozitive fără reîncărcarea întregului canvas.
- Media adăugată pe afiș rămâne ancorată corect la coordonatele posterului.
- Sunetul atașat unui afiș pornește când un rival îl scanează, conform regulii definite.
- Starea de teritoriu / echipă se actualizează și poate fi vizualizată în aplicație.
- Componentele bonus pot fi activate fără să afecteze stabilitatea sau latența principală.
- Imaginile de referință din `docs/project_definition/poze` pot fi folosite ca afișe-ancoră fără ajustări manuale în runtime.

Milestones (sprint-uri)
1. Scaffold proiect + Firebase init + autentificare + catalog de afișe-ancoră din imaginile de referință.
2. Detecție afiș + canvas local cu CustomPainter + mapare corectă pe poster.
3. Sincronizare Firestore pentru strokes, stickere și stare de colaborare.
4. Media ancorată: PNG / GIF / imagini + persistență + randare multi-device.
5. Territory engine + afișare stare echipă + declanșare audio la scanare.
6. Bonusuri creative: AI tag generator, haptics, glitch animation, polish și testare finală.

Răspunderi agenți
- `DiG_dev`: coordonare, planificare și delegare între implementarea mobilă și validarea runtime.
- `DiG_mobil`: implementare cod pentru AR, canvas, providers, services, UI, sincronizare și teste.
- `DiG_emulator`: rulare, debugging pe emulator / device, validare cameră, permisiuni, Firebase și comportament runtime.

Riscuri și atenție
- Limitări de cameră / AR pe emulator; unele scenarii trebuie validate pe device real.
- Costuri și latență Firebase pentru update-uri frecvente; folosiți actualizări incrementale și throttling unde e cazul.
- Dimensiunea media și performanța randării pot afecta mid-range devices.
- Reguli de securitate Firebase și maparea corectă a coordonatelor posterului trebuie testate înainte de demo.

Livrabile
- Cod sursă organizat (`models/`, `services/`, `providers/`, `screens/`, `widgets/`).
- README cu pași de configurare Firebase, cameră și rulare pe Android.
- Liste de teste / verificări manuale pentru scanare, colaborare multi-user, teritoriu, audio și maparea afișelor din setul de referință.
