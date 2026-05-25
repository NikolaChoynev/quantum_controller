# UVM Test Plan Template за Глава 3 и Глава 4

Този файл е работен test plan за UVM верификационната среда. Форматът е template-oriented: за всеки тест има ясно описание на stimulus-а, целта, проверките, coverage очакванията и бъдещите артефакти за Глава 4.

Важно: статус `PASS` може да се попълва само след реално изпълнена UVM симулация с UVM-capable simulator. До тогава полетата за резултати трябва да останат `TBD` или `NOT RUN`.

---

## 1. Общи изисквания за всички UVM тестове

| Поле | Изискване |
|---|---|
| DUT | `rtl/quantum_controller_top.sv` |
| Interface | `uvm/qc_if.sv` |
| Environment | `uvm/qc_env.sv` |
| Agent | `uvm/qc_agent.sv` в `UVM_ACTIVE` режим |
| Driver | `uvm/qc_driver.sv` |
| Monitor | `uvm/qc_monitor.sv` |
| Scoreboard | `uvm/qc_scoreboard.sv` |
| Coverage | `uvm/qc_coverage.sv` |
| Base test | `uvm/qc_base_test.sv` |
| Run script | `scripts/run_uvm.sh` |
| Simulator requirement | UVM-capable simulator: Questa/ModelSim, Xcelium или VCS |

Всеки test run за Глава 4 трябва да създаде или да посочи:

| Артефакт | Очаквана директория |
|---|---|
| UVM log | `results/uvm_logs/<test>.log` |
| Waveform | `results/uvm_waveforms/<test>.*` |
| Coverage database/report | `results/uvm_coverage/<test>/` |
| Seed metadata | В log файла и regression summary |
| PASS/FAIL status | В regression summary |

Минималните команди за работа с test plan-а са:

```bash
./scripts/run_uvm.sh --list
UVM_SIM=<questa|xcelium|vcs> SEED=1 ./scripts/run_uvm.sh qc_smoke_test
UVM_SIM=<questa|xcelium|vcs> SEED=1 ./scripts/run_uvm.sh all
```

При липса на UVM-capable simulator `scripts/run_uvm.sh` трябва да приключи с диагностично съобщение и без да записва `PASS`. Verilator остава само за non-UVM RTL regression flow-а.

За всеки реален Chapter 4 run трябва да се пазят следните данни:

| Поле | Как се използва във финалната дисертация |
|---|---|
| Test name | Име на executable UVM test класа |
| Sequence | Генерираният stimulus workload |
| Seed | Възпроизводимост на run-а |
| Status | PASS/FAIL/ERROR/NOT RUN |
| Log | Доказателство за UVM phases, scoreboard checks и грешки |
| Waveform | Доказателство за key timing/handshake сценарии |
| Coverage | Доказателство за functional coverage и missing bins |
| Ограничения | Toolchain, coverage gaps или known unsupported сценарии |

---

## 2. Regression summary template

| UVM test | Sequence | Category | Status | Seed | Log | Waveform | Coverage | Какво проверява |
|---|---|---|---|---:|---|---|---|---|
| `qc_smoke_test` | `qc_smoke_sequence` | Directed | NOT RUN | 1 | `results/uvm_logs/qc_smoke_test.log` | TBD | TBD | H → MEASURE → BRANCH |
| `qc_single_gate_test` | `qc_single_gate_sequence` | Directed | NOT RUN | 1 | `results/uvm_logs/qc_single_gate_test.log` | TBD | TBD | H/X/Z command path |
| `qc_cnot_test` | `qc_cnot_sequence` | Directed | NOT RUN | 1 | `results/uvm_logs/qc_cnot_test.log` | TBD | TBD | Two-qubit CNOT dependency |
| `qc_measure_test` | `qc_measure_sequence` | Directed | NOT RUN | 1 | `results/uvm_logs/qc_measure_test.log` | TBD | TBD | Measurement request/result path |
| `qc_wait_test` | `qc_wait_sequence` | Directed | NOT RUN | 1 | `results/uvm_logs/qc_wait_test.log` | TBD | TBD | WAIT hold/stall behavior |
| `qc_branch_test` | `qc_branch_sequence` | Directed | NOT RUN | 1 | `results/uvm_logs/qc_branch_test.log` | TBD | TBD | Conditional feedback branch |
| `qc_invalid_opcode_test` | `qc_invalid_opcode_sequence` | Directed negative | NOT RUN | 1 | `results/uvm_logs/qc_invalid_opcode_test.log` | TBD | TBD | Illegal opcode handling |
| `qc_random_test` | `qc_random_instruction_sequence` | Constrained-random | NOT RUN | TBD | `results/uvm_logs/qc_random_test.log` | TBD | TBD | Random valid instruction stream |
| `qc_dependency_stress_test` | `qc_dependency_stress_sequence` | Stress | NOT RUN | 1 | `results/uvm_logs/qc_dependency_stress_test.log` | TBD | TBD | Qubit dependency/stall behavior |
| `qc_bell_test` | `qc_algorithmic_bell_sequence` | Algorithmic | NOT RUN | 1 | `results/uvm_logs/qc_bell_test.log` | TBD | TBD | Bell-style H/CNOT/measure workload |
| `qc_ghz_test` | `qc_algorithmic_ghz_sequence` | Algorithmic | NOT RUN | 1 | `results/uvm_logs/qc_ghz_test.log` | TBD | TBD | GHZ-style CNOT chain workload |
| `qc_grover_like_test` | `qc_algorithmic_grover_like_sequence` | Algorithmic | NOT RUN | 1 | `results/uvm_logs/qc_grover_like_test.log` | TBD | TBD | Mixed gate/measure/branch workload |

---

## 3. Detailed test descriptions

### 3.1 `qc_smoke_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_smoke_sequence` |
| Stimulus | H върху q0, MEASURE q0 с measurement response, conditional BRANCH |
| Основна цел | Минимален end-to-end UVM сценарий през gate, measurement и feedback path |
| Изисквания | Driver трябва да подаде measurement response; monitor трябва да наблюдава command, measurement и feedback events |
| Scoreboard проверки | Gate command, measurement request/result, branch decision |
| Coverage цели | Opcode H/MEASURE/BRANCH, measurement result value, branch taken |
| Chapter 4 артефакти | log, waveform около MEASURE → result → BRANCH, coverage snapshot |

### 3.2 `qc_single_gate_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_single_gate_sequence` |
| Stimulus | H, X и Z инструкции |
| Основна цел | Проверка на еднокубитния gate command path |
| Изисквания | Няма measurement response |
| Scoreboard проверки | `gate_cmd_o`, opcode/target consistency |
| Coverage цели | OP_H, OP_X, OP_Z, command class gate |
| Chapter 4 артефакти | log, waveform на command outputs, opcode coverage |

### 3.3 `qc_cnot_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_cnot_sequence` |
| Stimulus | H q0, CNOT q0 → q1 |
| Основна цел | Проверка на двукубитен command path и control/target полета |
| Изисквания | CNOT трябва да има различни target/control qubits |
| Scoreboard проверки | CNOT command fields, gate command classification |
| Coverage цели | OP_CNOT, command class gate, control/target usage |
| Chapter 4 артефакти | log, waveform на issue/command stage |

### 3.4 `qc_measure_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_measure_sequence` |
| Stimulus | MEASURE q3 с measurement response value 1 |
| Основна цел | Проверка на measurement request/result path |
| Изисквания | Driver трябва да изчака `measure_request_valid_o` и да подаде result |
| Scoreboard проверки | Request qubit, result qubit/value, measurement state update |
| Coverage цели | Measurement request, response value 1, result value 1 |
| Chapter 4 артефакти | log, waveform на measurement_busy/request/result |

### 3.5 `qc_wait_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_wait_sequence` |
| Stimulus | H, WAIT, X |
| Основна цел | Проверка на WAIT hold/stall поведение |
| Изисквания | Scheduler status observation трябва да показва stall или busy/queue промяна |
| Scoreboard проверки | WAIT command classification, queue_count bounds |
| Coverage цели | OP_WAIT, command class wait, stall coverage |
| Chapter 4 артефакти | log, waveform на scheduler_stall и queue_count |

### 3.6 `qc_branch_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_branch_sequence` |
| Stimulus | MEASURE q2, conditional BRANCH, по-млада X инструкция |
| Основна цел | Проверка на feedback branch и flush behavior |
| Изисквания | Measurement result трябва да съвпадне с expected bit за taken branch |
| Scoreboard проверки | Branch target, branch_taken, condition_checked, queue flush expectation |
| Coverage цели | Branch taken, conditional/feedback/expected flags |
| Chapter 4 артефакти | log, waveform на feedback_valid/branch_taken/queue_count |

### 3.7 `qc_invalid_opcode_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_invalid_opcode_sequence` |
| Stimulus | Raw instruction с invalid opcode `4'hE` |
| Основна цел | Negative test за illegal instruction path |
| Изисквания | Invalid instruction не трябва да бъде issued като нормална команда |
| Scoreboard проверки | `illegal_instr_o` status observation |
| Coverage цели | Invalid opcode bin, illegal instruction status |
| Chapter 4 артефакти | log и waveform около invalid instruction accept |

### 3.8 `qc_random_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_random_instruction_sequence` |
| Stimulus | Random valid instruction stream |
| Основна цел | Разширяване на opcode/flag/resource coverage |
| Изисквания | Seed трябва да се записва в log; item_count трябва да е конфигурируем |
| Scoreboard проверки | Instruction/issue/command consistency, measurement/feedback where applicable |
| Coverage цели | Opcode coverage, opcode × flags, status/queue/busy bins |
| Chapter 4 артефакти | log със seed, coverage report, failing seed if any |

### 3.9 `qc_dependency_stress_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_dependency_stress_sequence` |
| Stimulus | Последователни операции върху общи qubit ресурси |
| Основна цел | Проверка на dependency tracker и scheduler stall поведение |
| Изисквания | Нужен е достатъчен drain time |
| Scoreboard проверки | Command order, queue_count bounds, illegal_issue absence |
| Coverage цели | Scheduler stall, busy qubit count, gate command coverage |
| Chapter 4 артефакти | waveform на qubit_busy/stall и coverage summary |

### 3.10 `qc_bell_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_algorithmic_bell_sequence` |
| Stimulus | H q0, CNOT q0→q1, MEASURE q0/q1 |
| Основна цел | Algorithmic Bell-style workload за gate + two-qubit + measurement path |
| Изисквания | Measurement response за двете измервания |
| Scoreboard проверки | Gate/CNOT command, measurement result correlation |
| Coverage цели | H, CNOT, MEASURE, measurement result values |
| Chapter 4 артефакти | log, waveform и coverage snapshot |

### 3.11 `qc_ghz_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_algorithmic_ghz_sequence` |
| Stimulus | H q0, CNOT chain, MEASURE q0/q1/q2 |
| Основна цел | Algorithmic GHZ-style multi-qubit dependency workload |
| Изисквания | По-дълъг drain time и multiple measurement responses |
| Scoreboard проверки | CNOT chain command consistency, measurement correlation |
| Coverage цели | Multi-qubit busy bins, CNOT, measurement bins |
| Chapter 4 артефакти | waveform на issue/command/measurement chain |

### 3.12 `qc_grover_like_test`

| Поле | Описание |
|---|---|
| Sequence | `qc_algorithmic_grover_like_sequence` |
| Stimulus | H/X/Z/CNOT/MEASURE/conditional BRANCH pattern |
| Основна цел | Смесен workload за gate, measurement и feedback path |
| Изисквания | Measurement response и branch expected bit |
| Scoreboard проверки | Mixed command classification, measurement, branch decision |
| Coverage цели | Broad opcode coverage, branch flags, measurement result, feedback outcome |
| Chapter 4 артефакти | log, waveform и coverage report |

---

## 4. Chapter 4 execution plan

Когато бъде наличен UVM-capable simulator, Глава 4 трябва да използва този test plan като изпълним regression списък.

Минималният Chapter 4 flow трябва да бъде:

```text
1. Потвърждаване на simulator toolchain.
2. Изпълнение на всички directed tests.
3. Изпълнение на random/stress tests с фиксирани seeds.
4. Изпълнение на algorithmic workload tests.
5. Събиране на logs, waveforms и coverage artifacts.
6. Попълване на regression summary таблицата.
7. Анализ на PASS/FAIL, coverage gaps и ограничения.
```

Не трябва да се описват coverage проценти, PASS статус или waveform резултати без реални файлове от `results/`.
