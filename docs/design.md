# Digitiamo Crew: agenti Claude sempre attivi sul server di casa

> Sostituisce il piano precedente (PWA + Managed Agents). Quello resta l'opzione per aprire il servizio ai colleghi in futuro.

## Context

Mirko vuole il suo "Grok Bot", costruito così:
- un **server a casa sua** sempre acceso;
- **un'istanza di Claude per ogni agente**, sempre in esecuzione, con cui parla dall'**app Claude** (telefono o desktop);
- ogni istanza **si compatta da sola e impara da sola**;
- una **skill centrale**, in questa cartella (`grockclone`), che controla le istanze e le fa evolvere.

Requisito già fissato: **più agenti devono lavorare in parallelo**. Già fissato anche il comportamento di un agente che lavora da solo: produce **solo bozze**, non invia mai nulla e non modifica mai nulla per conto suo.

Perché questa strada funziona. Le istanze sono **sessioni di Claude Code** collegate all'account claude.ai. Questo dà gratis tre cose:
- **i connettori claude.ai già attivi**: Gmail, Calendar, Drive, ClickUp, Fathom, Google Workspace… Si vedono anche in questa sessione come `mcp__claude_ai_*`;
- **le skill** già installate, come `mirko-email`;
- **Remote Control**, cioè la possibilità di parlare con ogni sessione dall'app Claude, senza aprire porte sul router.

## Architettura (fatti verificati sulla documentazione di Claude Code; le scelte mie sono indicate)

```
server di casa (Mac mini o Linux)
└── ~/crew/                         repo git: tutto è versionato, si può sempre tornare indietro
    ├── regia/                      sessione orchestratore + skill centrale `crew`
    ├── agents/<nome>/              una cartella per ogni agente
    │   ├── CLAUDE.md               identità, compito, regole, "Compact instructions"
    │   ├── .claude/settings.json   permessi (solo bozze), hook, soglia di compattazione, crossSessionInbound: accept
    │   ├── state/now.md            lavoro in corso (ripreso dopo ogni compattazione)
    │   ├── state/journal/AAAA-MM-GG.md   diario del giorno
    │   ├── state/lessons.md        lezioni apprese, sintetiche
    │   ├── proposals/              modifiche proposte a se stesso (CLAUDE.md, skill)
    │   ├── memory/                 memoria automatica (spostata qui con autoMemoryDirectory)
    │   └── routines.yaml           routine dell'agente (cron + prompt)
    ├── template/                   modello da cui nasce ogni agente
    ├── plugin/                     marketplace locale "digitiamo-crew": skill e hook comuni a tutti gli agenti
    └── bin/crewctl                 supervisore: avvia, ferma, stato, riavvio dopo crash o reboot
```

**1. Istanze sempre attive (scelta mia: tmux + supervisore).**
- Ogni agente gira come `claude --remote-control --name <nome>` nella sua cartella, in una finestra tmux dedicata: un processo per agente, quindi **parallelismo vero**.
- `crewctl` sta sotto launchd (Mac) o systemd (Linux). Al riavvio del server e quando un agente crasha, riprende ogni agente con `--continue`.
- Che launchd/systemd funzionino bene con Remote Control **non è documentato**: lo si prova in M1.
- Ho scartato `claude --bg` perché le sessioni non collegate si fermano dopo circa un'ora di inattività.
- Dall'app Claude, Remote Control mostra le sessioni con il nome dell'agente. Richiede un abbonamento claude.ai e non funziona con le chiavi API.

**2. Compattazione autonoma.**
- **Soglia anticipata** con `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (scelta mia: circa 60%), per compattare prima che il contesto sia pieno.
- **Regole di compattazione**: una sezione "Compact instructions" nel CLAUDE.md dell'agente dice cosa tenere nel riassunto (compito, decisioni, impegni aperti).
- **Hook `PreCompact`** (script): salva la coda della conversazione in `state/journal/` prima di ogni compattazione.
- **Hook `SessionStart` con matcher `compact`**: subito dopo la compattazione reinserisce `state/now.md` e `lessons.md` come contesto.
- **Regola di lavoro**: l'agente tiene sempre aggiornato `state/now.md`, così quello che conta sta su file e non solo nella conversazione.

**3. Autoapprendimento (scelta mia: l'agente impara, la regia decide).**
- Ogni sera parte una **riflessione** (routine): l'agente rilegge il diario, aggiorna `lessons.md` e la sua memoria, sfoltisce ciò che è superato e scrive in `proposals/` le modifiche che vorrebbe al proprio CLAUDE.md o alle proprie skill.
- L'agente **non modifica da solo le proprie istruzioni di base**. Serve a evitare che "derivi" nel tempo, e comunque Claude Code non lo fa senza una richiesta.

**4. La regia: skill `crew` in `grockclone`.**
È una sessione orchestratore sempre attiva. Comandi in italiano:
- **crea agente**: intervista breve, poi crea la cartella da `template/`, il commit e l'avvio;
- **stato**: per ogni agente dice se è attivo, cosa sta facendo (da `now.md`), ultima attività ed errori;
- **parla con / delega a**: messaggi tra sessioni con `SendMessage`/`ListAgents`, che passano per socket locale e non escono dal server;
- **evolvi**: ogni settimana, o su richiesta, legge diari, lezioni e proposte di ogni agente, decide cosa applicare, modifica CLAUDE.md e skill, fa il commit e il riavvio. Le migliorie utili a tutti le mette nel plugin comune;
- **routine**: tiene le pianificazioni di tutti gli agenti (`CronCreate`) e alle ore stabilite manda il messaggio "esegui la routine X" all'agente giusto. Le cron scadono dopo 7 giorni, quindi la regia le riarma ogni giorno da `routines.yaml`.

**5. Sicurezza e "solo bozze".**
- Il file `settings.json` di ogni agente **nega gli strumenti che inviano o scrivono** (per esempio `mcp__claude_ai_Gmail__send_message`, `send_gmail_message`, la creazione e modifica di task ClickUp) e **permette le bozze** (`create_draft`).
- I messaggi tra sessioni non possono approvare permessi né cambiare le impostazioni (garanzia di Claude Code).
- Mai `bypassPermissions`.

**6. Costi e limiti.**
- Tutte le istanze consumano lo **stesso abbonamento**. Un agente fermo in attesa non consuma niente; consumano messaggi, routine e riflessioni.
- Contesti lunghi costano di più a ogni nuovo turno: anche per questo la soglia di compattazione è anticipata.
- Uso **personale di Mirko**. Per darlo ai colleghi servono i loro account, oppure la strada Managed Agents con chiave API: la documentazione dice che i prodotti per terzi non possono usare il login claude.ai.

## Milestone

1. **M0 Server:** Claude Code ≥ 2.1.224 (serve per i messaggi tra sessioni), login claude.ai, tmux e git; repo `~/crew`; verifica che i connettori claude.ai e le skill compaiano anche sul server.
2. **M1 Un agente vivo:** `template/` + `crewctl` (start/stop/status/restart, unità launchd o systemd). Primo agente, per esempio "Assistente commerciale", raggiungibile dall'app Claude. Test di reboot e crash.
3. **M2 Compattazione:** hook PreCompact e SessionStart(compact), Compact instructions, `now.md`. Test con compattazione forzata.
4. **M3 Regia + parallelo:** skill `crew` (crea, stato, parla con) e tre agenti attivi insieme.
5. **M4 Apprendimento ed evoluzione:** riflessione serale, proposte, evoluzione settimanale con commit, plugin comune.
6. **M5 Routine:** `routines.yaml`, cron gestite dalla regia, regola "solo bozze".

## Verifica

- **Parallelo (criterio principale):** dall'app Claude assegno compiti lunghi a 3 agenti nello stesso momento, e tutti e 3 lavorano insieme (`/peers` e tmux mostrano 3 sessioni attive).
- **Sempre attivo:** riavvio il server; entro pochi minuti tutti gli agenti sono di nuovo raggiungibili dall'app e hanno ripreso la conversazione.
- **Compattazione:** forzo `/compact` su un agente a metà lavoro; dopo, sa ancora cosa stava facendo (`now.md` reinserito) e il diario contiene il salvataggio.
- **Apprendimento:** correggo un agente ("le mail ai clienti in HTML, firma corta"); il giorno dopo la lezione è in `lessons.md` e viene applicata; l'evoluzione settimanale la porta nel CLAUDE.md con un commit.
- **Solo bozze:** una routine che "manda il riepilogo al cliente" produce una bozza Gmail; il tentativo di invio viene negato.
- **Regia:** "crea agente PM" produce cartella, commit e sessione attiva senza interventi manuali.

## Da verificare in M0–M1

- Remote Control sotto launchd/systemd (documentato solo tmux/screen).
- Il formato esatto dell'input dell'hook PreCompact.
- Che i messaggi tra sessioni funzionino tra processi avviati dal supervisore.
- La disponibilità dei connettori claude.ai in sessioni non interattive.
