# Cold War RTS Lobby: Einfüge-Paket für Place1

Mit diesen Dateien fügst du die komplette Lobby in einen bestehenden Place
ein (z. B. Place1), ohne dessen übrigen Inhalt zu ersetzen.

**Stand des Pakets:** Lobby-Version 5, gebaut am 25.09.2026 (Commit `66541d9`
auf `claude/cold-war-rts-lobby-alujz1`), 11.824 Teile.

> **Ehrlich vorweg:** Alles wurde außerhalb von Roblox gebaut und getestet
> (Typprüfung und 101 automatische Tests in einer Lune-Nachbildung der
> Roblox-Dienste). In **Roblox Studio wurde es noch nie geöffnet.** Was
> das genau bedeutet, steht in Abschnitt 8.

---

## 1. Inhalt

| Datei | Größe | Einfügen in | Inhalt |
|---|---|---|---|
| `1_Workspace_ColdWarLobby.rbxm` | 326 KB | **Workspace** | die ganze Basis als Model `ColdWarLobby` (11.824 Teile, keine Skripte) |
| `2_ReplicatedStorage_Lobby.rbxm` | 38 KB | **ReplicatedStorage** | Ordner `Lobby`: Einstellungen (Modi, Karten, Einheiten, Missionen, Events, Farben, Sounds), Remotes, Hilfsmodule |
| `3_ServerScriptService_LobbyServer.rbxm` | 211 KB | **ServerScriptService** | Server-Skript `LobbyServer` mit 50 Modulen |
| `4_StarterPlayerScripts_LobbyClient.rbxm` | 88 KB | **StarterPlayer → StarterPlayerScripts** | LocalScript `LobbyClient` mit 23 Modulen (Oberfläche, Kamera, Ambiente) |
| `5_ServerStorage_LobbyAssets.rbxm` | 0,2 KB | **ServerStorage** | leerer Ordner `LobbyAssets/Units` für eigene Fahrzeugmodelle (Abschnitt 6) |
| `ColdWarLobby.rbxl` (nur im Zip) | 663 KB | – | derselbe Stand als fertige Place-Datei (Alternative in Abschnitt 3) |

---

## 2. Einfügen, Schritt für Schritt

1. **Sicherung:** Speichere zuerst eine Kopie von Place1 (z. B. *File → Save to File As…*).
2. **Ältere Version zuerst entfernen.** Hast du schon einmal ein Lobby-Kit
   eingefügt, lösche diese fünf Teile, sonst gibt es die Lobby doppelt
   (überall doppelte, flimmernde Teile, alte Skripte laufen mit):
   - `Workspace.ColdWarLobby`
   - `ReplicatedStorage.Lobby`
   - `ServerScriptService.LobbyServer`
   - `StarterPlayer.StarterPlayerScripts.LobbyClient`
   - `ServerStorage.LobbyAssets`

   Eigene Fahrzeugkopien in `LobbyAssets/Units` vorher herausziehen.
3. **Die fünf Dateien einfügen.** Im Explorer Rechtsklick auf den Zieldienst
   aus der Tabelle, dann **„Insert from File…“**, dann die passende Datei
   wählen. Je nach Sprache der Studio-Oberfläche heißt der Eintrag etwas
   anders, z. B. „Aus Datei einfügen…“.
   - **Nicht** die Dateien ins 3D-Fenster ziehen: Dann landet alles im
     Workspace, und die Skripte laufen am falschen Ort.
   - `4_…LobbyClient` muss **in StarterPlayerScripts** liegen, nicht direkt
     in StarterPlayer. Dort würde das LocalScript nicht starten.
   - Die Reihenfolge ist egal. Vor dem Start müssen aber alle fünf drin sein.
4. **Beleuchtung (empfohlen):** Im Explorer **Lighting** wählen und im
   Eigenschaftenfenster **Technology** auf **ShadowMap** stellen. Das ist
   das Einzige, was Skripte nicht selbst einstellen dürfen.
5. **Play drücken.** Erwartet:
   - Im Output steht `[Lobby] Moved template Baseplate, SpawnLocation to ServerStorage.LobbyDisplacedTemplate`, falls diese Vorlagenteile existieren.
   - Hat Studio die Lobby beim Einfügen versetzt, steht dort außerdem `[Lobby] Moved the lobby … studs back to the world origin`. Das ist gewollt.
   - Du erscheinst auf einem der 8 gelb umrandeten Spawn-Felder, Blick nach Norden auf das Operations Center.
6. Wenn alles passt: speichern bzw. veröffentlichen.

**Nur optisch, nicht nötig:** Liegt die Lobby im Bearbeitungsmodus versetzt,
richtet diese Zeile in der Command Bar sie am Ursprung aus (in Studio nicht
getestet; beim Start passiert es ohnehin automatisch):
```lua
local l = workspace.ColdWarLobby; l:PivotTo(l.LobbyOrigin.CFrame:Inverse() * l:GetPivot())
```

---

## 3. Alternative: fertige Place-Datei

`ColdWarLobby.rbxl` in Studio öffnen und Play drücken. Mit *File → Publish
to Roblox As…* kannst du sie über einen bestehenden Place veröffentlichen.
**Achtung:** Das ersetzt den kompletten Inhalt dieses Places. Um Place1 zu
behalten, nimm den Weg aus Abschnitt 2.

---

## 4. Was die Skripte beim Start an deinem Place ändern

Das passiert nur während des Spiels (Play bzw. Live-Server). Im
Bearbeitungsmodus bleibt dein Place unverändert, außer beim Neuaufbau aus
Abschnitt 7.

- **Spawns und Baseplate:** Alle `SpawnLocation`s und alle Teile mit dem
  Namen `Baseplate`, die *direkt* im Workspace liegen, werden nach
  `ServerStorage.LobbyDisplacedTemplate` **verschoben, nicht gelöscht**.
  Das betrifft auch **deine eigenen** SpawnLocations. Liegen sie in einem
  Ordner oder Model, bleiben sie stehen, aber dann können Spieler auch dort
  erscheinen.
- **Position:** Die Lobby ist fest an den Weltursprung (0, 0, 0) gebunden.
  Verschiebst oder drehst du sie, wird das beim Start rückgängig gemacht.
  Sie belegt mit Boden, Hügeln und Wald etwa **2048 × 2048 Studs** um den
  Ursprung. Alles andere in diesem Bereich überschneidet sich mit ihr,
  auch **Terrain**. Das sollte dort entfernt werden.
- **Beleuchtung:** Der Server setzt Uhrzeit (15:36), Helligkeit, Umgebungs-
  licht und Schatten. Er legt Atmosphere, Sky, Farbkorrektur, Bloom und
  SunRays an, vorhandene werden weiterverwendet und umgestellt. Tiefen-
  unschärfe (DepthOfField) wird ausgeschaltet.
- **Kamera:** Der maximale Zoom wird auf 55 Studs begrenzt. Die Grenze wird
  nur verkleinert, nie vergrößert.
- **Sonst nichts:** Laufgeschwindigkeit, Roblox-Standardoberfläche
  (CoreGui) und StarterGui bleiben unangetastet. Die Oberfläche der Lobby
  bauen die Skripte beim Start selbst.

---

## 5. Was im Studio geht und was erst im veröffentlichten Spiel

| Funktion | Im Studio-Test | Im veröffentlichten Spiel |
|---|---|---|
| Matchmaking (Terminals, Warteschlangen, private Lobbys) | funktioniert, der Einsatz wird aber **nur simuliert** („DEPLOYMENT SIMULATED …“) | echter Teleport, sobald `TargetPlaceId` gesetzt ist (siehe unten) |
| Spielerdaten (Rang, Credits, Missionen) | ohne API-Zugriff **vorübergehend**, mit Demo-Werten (in der Oberfläche gekennzeichnet) | gespeichert im DataStore `ColdWarLobby_Commanders_v1` |
| Bestenlisten | ohne API-Zugriff: Einträge dieses Servers plus Demo-Einträge | global aus den OrderedDataStores `ColdWarLobby_LB_v1_…` |
| Sounds | laden, falls die Creator-Store-IDs verfügbar sind | ebenso |

So ist es programmiert und in der Nachbildung getestet. In Studio selbst ist
auch das **NICHT VERIFIZIERT**.

**Teleport in das RTS-Spiel:**
1. In `ReplicatedStorage › Lobby › Config › GameModes` bei `Settings`
   `TargetPlaceId = 0` durch die Place-ID des RTS-Places ersetzen.
2. Veröffentlichen und im **Roblox-Client** testen. Laut Roblox-Doku
   funktioniert TeleportService im Studio-Test grundsätzlich nicht.
3. Die Lobby schickt jedes Match auf einen **reservierten Server**
   (`TeleportAsync` mit `ShouldReserveServer`). Reservierte Server gehen
   nur für Places, über die du verfügst. Nach Aussagen im Roblox-
   Entwicklerforum ist das über Experience-Grenzen hinweg nicht möglich.
   Sicher klappt es, wenn der RTS-Place **ein Place derselben Experience**
   ist wie die Lobby (Creator Dashboard → Experience → Places). Ob das
   Fulda-Gap-Spiel so eingerichtet ist, weiß ich nicht. Ich habe es nie
   geöffnet oder verändert. **NICHT VERIFIZIERT.**
4. Der RTS-Place kann die Match-Daten optional über
   `player:GetJoinData().TeleportData` lesen:
   `{ source, mode, map, teams = { {userIds}, {userIds} }, private }`.

**Echtes Speichern im Studio testen:** Place veröffentlichen, dann unter
*Experience Settings* (früher *Game Settings*) → *Security* die Option
**„Enable Studio Access to API Services“** einschalten.

---

## 6. Fahrzeuge aus Fulda Gap verwenden, ohne das Spiel zu ändern

Die Lobby baut ihre Fahrzeuge selbst als einfache Low-Poly-Modelle.
**Aus Fulda Gap wurde nichts übernommen und nichts verändert**, weil ich
keinen Zugriff darauf hatte. Echte Modelle kannst du so einsetzen:

1. Fulda Gap in Studio öffnen, das Fahrzeugmodell markieren und
   **kopieren** (Strg+C). Dort **nichts speichern**.
2. In Place1 in `ServerStorage › LobbyAssets › Units` einfügen.
3. Das Modell genau nach der Einheit bzw. dem Modellschlüssel benennen:

| Einheit (ID) | Modellschlüssel |
|---|---|
| `M1_ABRAMS`, `LEOPARD_2` | `MBT_WEST` |
| `M2_BRADLEY` | `IFV_WEST` |
| `M113` | `APC_TRACKED` |
| `M163_VADS` | `SPAAG_WEST` |
| `M35_TRUCK` | `TRUCK_WEST` |
| `M151_JEEP` | `JEEP` |
| `T72`, `T80`, `T80BV_ZIMA` | `MBT_EAST` |
| `BMP2` | `IFV_EAST` |
| `BTR70` | `APC_WHEELED` |
| `ZSU234` | `SPAAG_EAST` |
| `URAL_4320` | `TRUCK_EAST` |
| `BRDM2` | `SCOUT_WHEELED` |
| (nur Kulisse) | `HELICOPTER`, `CAR_SEDAN`, `CAR_SMALL`, `VAN` |

Ein Modell mit dem Namen der ID gilt nur für diese Einheit. Ein Modell mit
dem Namen des Schlüssels gilt für alle Einheiten mit diesem Schlüssel,
solange keine eigene ID-Kopie da ist.

**Klarstellung, wo die Kopien auftauchen:** Das stand in der englischen
README vorher zu pauschal.
- **Sofort beim nächsten Play:** das Fahrzeug auf der Garagen-Drehscheibe
  und die Vorschauen in der Fahrzeugliste. Diese Modelle erzeugt der
  Server bei jedem Start neu.
- **Erst nach einem Neuaufbau (Abschnitt 7):** die fest eingebauten
  Fahrzeuge der vorgebackenen Lobby, also Fahrbereitschaft, Parkplatz,
  Hubschrauber am Landeplatz und das Event-Fahrzeug im Winterhof.
- Kopien werden verankert und bei Bedarf **verkleinert, nie vergrößert**.
  Der Hubschrauber am Landeplatz wird gar nicht skaliert.
- `Script`s und `LocalScript`s werden aus den Kopien entfernt, damit keine
  Spiellogik des RTS in der Lobby läuft. ModuleScripts bleiben, starten
  aber nicht von selbst.
- Tarnschemata färben Kopien nur um, wenn deren Teile `Paint`-Attribute
  haben (`Base`/`Accent`). Sonst behalten sie ihre Farben.

---

## 7. Neuaufbau der Lobby

Nur nötig für Fahrzeugkopien in der fest eingebauten Kulisse oder wenn du
Code der Welt änderst. Im Bearbeitungsmodus in der Command Bar:
```lua
require(game.ServerScriptService.LobbyServer.World.Builder).Build()
```
- Löscht `Workspace.ColdWarLobby` und baut die Lobby neu am Ursprung
  (das kann einen Moment dauern). **Deine eigenen Änderungen an diesem Model gehen
  dabei verloren.**
- Übernimmt dabei auch die Lobby-Beleuchtung (Abschnitt 4) in `Lighting`,
  und die wird dann mit dem Place gespeichert.
- Alternative: `Workspace.ColdWarLobby` löschen und Play drücken. Dann
  baut der Server die Lobby bei jedem Start neu, im Bearbeitungsmodus ist
  sie aber nicht sichtbar.
- **NICHT VERIFIZIERT in Studio.** Dieselbe Funktion baut in den Tests und
  beim Backen dieses Pakets die Lobby, dort aber außerhalb von Studio.

---

## 8. Klarstellungen: was „getestet“ heißt und was nicht

**Automatisch geprüft (101 Tests, alle bestanden):**
- Die Skripte laufen in der Nachbildung fehlerfrei. Server und Client
  arbeiten über die echten Remotes zusammen, alle Terminals und Panels
  funktionieren.
- Matchmaking-Logik, Missionen, Bestenlisten, Events, Garage, DataStore-
  Fehlerfälle und das Zusammenführen beim Speichern.
- Jede Tür und jede Station ist vom Spawn aus zu Fuß erreichbar (2,5D-
  Navigationsanalyse), in höchstens 8,7 s bis zu jedem Eingang.
- Nichts schwebt, nichts steckt ineinander, keine Fläche flimmert
  (Z-Fighting), kein Teil steht vor einer Beschriftung, Schilder sitzen
  bündig, jede Zone ist von den Spawn-Feldern aus beschildert.
- Die Dateien dieses Pakets entsprechen genau dem Quellcode. In einen
  nachgebildeten leeren Baseplate-Place eingefügt, auch versetzt, startet
  die Lobby richtig.

**Nicht geprüft, weil nur Roblox selbst das kann:**
- die echte Darstellung: Licht, Schatten, Materialien wie Plaster,
  ClayRoofTiles und Sandstone, Schriften, genaue Textgrößen (Roblox'
  TextScaled schätze ich nur nach)
- Physik und Charaktersteuerung (Stufen, Kanten, Kamera in engen Räumen)
- mehrere Spieler über ein echtes Netzwerk
- DataStores und Teleports im veröffentlichten Spiel
- ob die Sound-IDs laden
- Leistung auf Handys, StreamingEnabled

**Weitere Klarstellungen:**
- Die Vorschaubilder im Repository (`docs/previews`) stammen aus einem
  eigenen, **vereinfachten** Renderer. Es sind keine Screenshots aus
  Roblox. Farben, Licht, Schatten und Textgrößen weichen ab.
- Maßstab: 1 Stud entspricht etwa 0,3 m. Die Fahrzeuge sind verkleinert
  (etwa 60 %), damit sie in die kompakte Basis passen.
- „Place1“ ist nur der Standardname neuer Places. Die Anleitung gilt für
  jeden Place.
- Umfang: rund 11.800 Teile, 70 Lichter (43 tagsüber an, keines wirft
  Schatten), 271 SurfaceGuis. Das meiste ist Deko ohne Kollision.
- Bekannte kleine Punkte:
  - Von einem der 8 Spawn-Felder steht der Wegweiser vor dem östlichen
    CANTEEN-Schild. Sein CANTEEN-Pfeil nennt die Kantine aber selbst.
  - Auf Handys ist der Text klein. Das ist auf keinem Gerät geprüft.
  - Namen in den Bestenlisten laden beim ersten Mal langsam.

---

## 9. Kurz-Check nach dem ersten Play

- [ ] Spawn auf einem gelben Feld, Blick zum Operations Center
- [ ] Zu Fuß in jedes Gebäude, ohne zu springen
- [ ] An einer Station **E** drücken: Panel öffnet sich, **X** schließt es
- [ ] Schilder vom Platz aus lesbar, auch CANTEEN hinter dem Einsatzbrett
- [ ] Nichts flimmert, nichts schwebt
- [ ] Output ohne rote Fehlermeldungen (Sound-Warnungen notieren)

Die ausführliche Liste mit allen manuellen Studio-Prüfungen steht in
`STUDIO_TEST_PLAN.md` (Englisch, im Zip enthalten).

---

## 10. Wenn etwas nicht stimmt

| Beobachtung | Ursache und Lösung |
|---|---|
| Alles flimmert, Teile doppelt | Eine ältere Version wurde nicht gelöscht (Schritt 2) |
| Output: `Baked lobby is version … rebuilding` | Workspace-Model und Skripte stammen aus verschiedenen Paketen. Alle fünf Dateien aus demselben Paket einfügen |
| Keine Lobby-Oberfläche, kein Prompt | `LobbyClient` liegt nicht in `StarterPlayerScripts`, oder `Lobby` fehlt in ReplicatedStorage |
| Du erscheinst woanders | Eine eigene SpawnLocation in einem Ordner (Abschnitt 4) |
| Graue Fläche oder Gelände schaut durch den Boden | Terrain oder Teile von Place1 im Lobby-Bereich (Abschnitt 4) |
| Licht wirkt flach | Lighting → Technology auf ShadowMap stellen |
| „DEPLOYMENT SIMULATED …“ | Normal im Studio und solange `TargetPlaceId = 0` (Abschnitt 5) |
| `Failed to load sound` | Sound-ID nicht verfügbar. In `ReplicatedStorage › Lobby › Config › Sounds` ersetzen |
