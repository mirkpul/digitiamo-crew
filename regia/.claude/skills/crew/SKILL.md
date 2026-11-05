---
name: crew
description: Gestisce la Digitiamo Crew, cioè gli agenti Claude Code sempre attivi sul server. Serve a creare un agente, vedere lo stato, parlare con un agente o delegargli un compito, riarmare le routine, far evolvere gli agenti dalle loro lezioni e proposte, riavviare o fermare un agente. Usala per frasi come "crea un agente", "come stanno gli agenti", "chiedi a X", "delega a X", "riarma", "evolvi", "riavvia X", e per ogni messaggio "/crew <comando>".
---

# Skill `crew` — regia della Digitiamo Crew

Struttura (CREW_HOME = la cartella padre di `regia/`):
- `bin/crewctl`: supervisore (`new`, `start`, `stop`, `restart`, `status`, `attach`, `logs`, `list`);
- `agents/<nome>/`: un agente, con `CLAUDE.md`, `.claude/settings.json`, `state/now.md`, `state/journal/`,
  `state/lessons.md`, `proposals/`, `memory/`, `routines.yaml`;
- `template/`: modello da cui nasce ogni agente;
- `agents/` è un repo git **locale e privato**, separato dal repo pubblico della crew: i commit sugli agenti vanno lì (`git -C ../agents ...`);
- `lib/hooks/`: hook di compattazione comuni.

Gli agenti sono sessioni con nome uguale alla cartella. Si raggiungono con `ListAgents` / `SendMessage`
(nome = nome dell'agente). Esegui `crewctl` come `../bin/crewctl` dalla cartella `regia/`.

Leggi il comando richiesto (il primo argomento, oppure l'intento della frase) e segui la procedura corrispondente.

---

## crea
1. Se mancano, chiedi **una domanda alla volta**: il nome (breve, minuscolo, es. `commerciale`), poi il compito in
   una frase, poi gli strumenti principali e le eventuali routine (per esempio un brief ogni mattina).
2. `../bin/crewctl new <nome> "<compito>"`.
3. Arricchisci `../agents/<nome>/CLAUDE.md` nella sezione "Il tuo compito": responsabilità, fonti, cosa produce,
   cosa non deve fare. Resta specifico, niente agenti "tuttofare".
4. Aggiungi le routine richieste in `../agents/<nome>/routines.yaml` (la `riflessione` c'è già).
5. Commit nel repo privato degli agenti: `git -C ../agents add <nome> && git -C ../agents commit -m "nuovo agente <nome>"`.
6. `../bin/crewctl start <nome>`, poi esegui **riarma** solo per questo agente.
7. Rispondi: nome, compito, routine, e che dall'app Claude lo trova tra le sessioni Remote Control come `<nome>`.

## stato
1. `../bin/crewctl status`.
2. `ListAgents` per vedere quali sessioni sono raggiungibili.
3. Per ogni agente leggi la prima sezione di `state/now.md` e l'ultima voce del diario di oggi.
4. Rispondi con una tabella breve: agente, attivo/fermo, cosa sta facendo, ultimo aggiornamento, problemi
   (agente fermo, diario vuoto da giorni, proposte in attesa in `proposals/`).

## parla / delega
1. Individua l'agente giusto dal compito (leggi le sezioni "Il tuo compito" se serve). Se nessuno è adatto,
   proponi di crearne uno.
2. `SendMessage` all'agente con un brief autosufficiente: obiettivo, contesto, scadenza, formato del risultato e
   la frase "Lavori da solo: solo bozze, niente invii o modifiche esterne. Quando hai finito rispondimi con
   SendMessage."
3. Annota in `state/now.md` della regia: agente, compito, quando l'hai delegato.
4. Più agenti possono lavorare in parallelo: per compiti indipendenti manda tutti i messaggi subito, uno per agente.
5. Quando arriva la risposta, togli il compito da `state/now.md` e riferisci a Mirko il risultato e dove trovare
   le bozze.

## riarma
Le pianificazioni (`CronCreate`) durano al massimo 7 giorni e si perdono a un riavvio, quindi vanno riarmate.
1. `CronList` e cancella con `CronDelete` le pianificazioni della crew già presenti (prompt che iniziano con
   `[crew]`), così non ci sono doppioni.
2. Leggi `routines.yaml` della regia e di ogni agente in `../agents/*/`.
3. Per ogni routine crea una pianificazione `CronCreate` con l'espressione cron della routine (fuso
   `Europe/Rome`) e questo prompt:
   - per un agente: `[crew] SendMessage a <agente>: "<prompt della routine>"`;
   - per la regia: `[crew] <prompt della routine>`.
4. Quando una pianificazione `[crew] SendMessage a <agente>: ...` scatta, manda quel messaggio all'agente con
   `SendMessage`. Se l'agente non è raggiungibile, `../bin/crewctl start <agente>` e riprova una volta.
5. Rispondi con l'elenco delle routine armate (agente, nome, quando).

## evolvi
Fa crescere gli agenti in base a ciò che hanno imparato. Gira ogni sabato e su richiesta.
1. Per ogni agente leggi: `state/lessons.md`, i diari degli ultimi 7 giorni, i file in `proposals/` non ancora
   valutati.
2. Per ogni proposta decidi:
   - **applica**: la proposta è supportata da episodi concreti nel diario, è coerente con il compito e non
     allarga i permessi;
   - **chiedi a Mirko**: cambia il compito, aggiunge strumenti o permessi, o tocca più agenti;
   - **scarta**: un caso isolato, oppure già coperto da una lezione.
3. Promuovi in `CLAUDE.md` le lezioni stabili, cioè confermate da più episodi, e toglile da `lessons.md`, così
   `lessons.md` resta corto.
4. Se più agenti hanno imparato la stessa cosa, valuta se portarla in `template/CLAUDE.md` per i prossimi agenti.
5. Sposta le proposte valutate in `proposals/archivio/` aggiungendo in cima l'esito (`applicata`, `scartata`,
   `in attesa di Mirko`) e il motivo.
6. Un commit per agente nel repo privato: `git -C ../agents add <agente> && git -C ../agents commit -m "<agente>: evoluzione settimanale — <sintesi>"`. Se modifichi `template/`, fai il commit nel repo della crew (`git -C .. commit`).
7. Riavvia gli agenti modificati con `../bin/crewctl restart <agente>`, perché il CLAUDE.md si rilegge all'avvio.
   Prima avvisa l'agente con `SendMessage` e aspetta che abbia aggiornato `state/now.md`.
8. Rispondi a Mirko con un riepilogo per agente (cosa è cambiato) e le domande in attesa, **una alla volta**.

## riavvia / ferma / avvia
Usa `../bin/crewctl restart|stop|start <nome>`. Prima di fermare o riavviare un agente al lavoro, chiedigli con
`SendMessage` di salvare lo stato in `state/now.md`.

## Regole per la regia
- Non dare mai agli agenti permessi di invio o modifica nei sistemi esterni per il lavoro autonomo.
- Non modificare `.claude/settings.json` di un agente senza l'ok esplicito di Mirko: sono i suoi permessi.
- Mai `git push`, mai cancellare la cartella di un agente senza l'ok esplicito di Mirko.
