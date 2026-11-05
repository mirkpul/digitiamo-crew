# Digitiamo Crew

Un team di **collaboratori virtuali sempre attivi**, ispirato a Grok Bot e costruito interamente su **Claude Code**.

- **Un'istanza per agente.** Ogni agente è una sessione Claude Code a sé, con la sua cartella, il suo compito,
  la sua memoria e le sue routine. Le sessioni girano tutte insieme, quindi più agenti lavorano davvero in parallelo.
- **Sempre attivi.** Un server di casa (Linux) tiene accese le sessioni con tmux e le riavvia da solo dopo un
  crash o un reboot.
- **Dall'app Claude.** Con Remote Control parli con ogni agente dal telefono o dal desktop, senza aprire porte sul
  router.
- **Strumenti già pronti.** Gli agenti usano l'account claude.ai, quindi hanno già i connettori collegati (Gmail,
  Calendar, Drive, ClickUp, Fathom…) e le skill installate.
- **Compattazione autonoma.** Le soglie sono anticipate e il CLAUDE.md di ogni agente contiene le *Compact
  instructions*. Prima di ogni compattazione un hook salva nel diario gli ultimi scambi e lo stato; subito dopo, un
  altro hook reinserisce lo stato di lavoro e le lezioni apprese.
- **Autoapprendimento.** Ogni agente annota lezioni e diario e, ogni sera, fa una riflessione da cui nascono proposte
  di modifica a se stesso.
- **Regia centrale.** Una sessione `regia` con la skill `crew` crea gli agenti, delega i compiti, arma le routine e
  ogni settimana fa evolvere le istruzioni degli agenti con commit git, così ogni modifica si può annullare.
- **Solo bozze quando lavorano da soli.** Gli invii e le modifiche nei sistemi esterni chiedono sempre conferma, e
  le cancellazioni sono vietate.

## Struttura

```
bin/crewctl                      supervisore (new, start, stop, restart, status, attach, logs, install-systemd)
systemd/digitiamo-crew.service   avvio automatico al boot (systemd --user)
lib/hooks/precompact.sh          hook PreCompact → salva nel diario prima della compattazione
lib/hooks/session-context.sh     hook SessionStart → reinserisce now.md, lessons.md e routine
template/                        modello di agente (CLAUDE.md, settings.json, state/, routines.yaml)
regia/                           sessione orchestratore + skill .claude/skills/crew
agents/<nome>/                   agenti reali: repo git locale privato, mai nel repo pubblico
```

## Requisiti

- Server Linux sempre acceso con `bash` ≥ 4, `tmux`, `git` e `jq`.
- Claude Code ≥ 2.1.224, che serve per i messaggi tra sessioni.
- Login con un **abbonamento claude.ai**: Remote Control non funziona con le chiavi API, e `ANTHROPIC_API_KEY` non
  deve essere impostata.

## Installazione

```bash
git clone <questa-repo> ~/crew && cd ~/crew
claude                      # primo avvio interattivo: login claude.ai e trust della cartella, poi /exit
./bin/crewctl new commerciale "Segue i lead: bozze di follow-up e riepiloghi delle call."
./bin/crewctl start --all   # regia + agenti
./bin/crewctl status
./bin/crewctl install-systemd && sudo loginctl enable-linger $USER   # riparte da sola al boot
```

Al primo avvio di ogni cartella Claude Code chiede di confermare la fiducia (trust): fallo una volta con
`crewctl attach <nome>` (`Ctrl-b d` per uscire da tmux).

Dall'app Claude, apri la lista delle sessioni Remote Control: trovi `regia` e un'entrata per ogni agente.

## Uso

Dall'app, scrivi alla **regia**:
- "crea un agente PM che segue i progetti su ClickUp e mi fa il SAL il venerdì"
- "come stanno gli agenti?"
- "delega a commerciale e a pm: prepara il riepilogo settimanale dei loro clienti" (i due lavorano in parallelo)
- "evolvi"

Oppure scrivi direttamente al singolo agente.

## Come impara un agente

| File | Chi lo scrive | Quando |
|---|---|---|
| `state/now.md` | l'agente | sempre: lavoro in corso, prossimi passi |
| `state/journal/AAAA-MM-GG.md` | l'agente + hook PreCompact | a ogni compito concluso, a ogni compattazione |
| `state/lessons.md` | l'agente | quando viene corretto; ripulito ogni sera |
| `proposals/` | l'agente | riflessione serale |
| `CLAUDE.md` | solo la regia | evoluzione settimanale, con commit |

## Limiti noti (da verificare sul server)

- La documentazione di Claude Code prevede tmux/screen per le sessioni Remote Control persistenti, mentre l'avvio
  da systemd qui è una scelta nostra.
- Le pianificazioni `CronCreate` durano al massimo 7 giorni: la regia le riarma ogni notte (`/crew riarma`).
- Tutte le sessioni consumano lo stesso abbonamento. Un agente fermo in attesa non consuma niente.
- È pensato per uso personale. Per darlo ad altre persone serve un account claude.ai ciascuno.

## Licenza

MIT
