# ГЛАВА 2: RTL архитектура на квантовия контролер

## Работен Markdown файл

Този файл е Git-friendly работна версия за писане и структуриране на Глава 2. Целта му е да позволи редактиране в VS Code, Codex или друг текстов редактор, без да се разчита само на `.docx` файл.

Официалният `.docx` документ може да бъде обновяван на базата на този Markdown текст.

---

# 2.1 Архитектурна концепция

Глава 2 представя реализираната RTL архитектура на instruction-driven квантов контролер. За разлика от теоретичния анализ в Глава 1, тук фокусът е върху конкретната цифрова архитектура, разработените SystemVerilog модули, техните интерфейси, вътрешния поток на данни и симулационната проверка.

Предложеният контролер обработва квантови операции под формата на фиксирани 32-битови инструкции. Всяка инструкция съдържа код на операцията, идентификатори на кубити, времева продължителност и управляващи флагове. След приемане на инструкцията контролерът я декодира, буферира, проверява за зависимости, планира за изпълнение и я преобразува в цифрови command сигнали към абстрактен quantum execution layer.

Реализираната архитектура не моделира физическото квантово устройство. Не се генерират аналогови импулси, не се симулира шум, не се моделира декохерентност и не се описва конкретна технология за физически кубити. Целта е да се изследва класическият цифров контролен слой, който управлява логическата последователност от квантови операции.

Основният поток през контролера е:

```text
raw 32-bit instruction
→ instruction_decoder
→ operation_queue
→ scheduler
→ execution_controller
→ measurement_controller
→ feedback_unit
→ command / measurement / branch outputs
```

Основни RTL файлове, свързани с този раздел:

```text
rtl/qc_pkg.sv
rtl/instruction_decoder.sv
rtl/operation_queue.sv
rtl/dependency_tracker.sv
rtl/scheduler.sv
rtl/execution_controller.sv
rtl/measurement_controller.sv
rtl/feedback_unit.sv
rtl/quantum_controller_top.sv
```

---

## 2.1.1 Системни изисквания

Реализираният контролер е разработен според няколко основни системни изисквания. Първото изискване е поддръжката на instruction-driven модел, при който квантовите операции се представят като цифрови инструкции. Това позволява входната квантова програма да бъде обработвана от хардуерна логика по структуриран и формализиран начин.

Второто изискване е наличието на модул за декодиране на инструкции. Той трябва да извлича от входната дума основните полета: `opcode`, `target_qubit`, `control_qubit`, `duration`, `flags` и `reserved`. Това поведение е реализирано в `rtl/instruction_decoder.sv`.

Третото изискване е управление на зависимости между операции. Когато две операции използват един и същ кубит, те не трябва да бъдат издавани едновременно или в неправилен ред. Това е реализирано чрез `rtl/dependency_tracker.sv` и `rtl/scheduler.sv`.

Четвъртото изискване е поддръжка на measurement и feedback сценарии. Измерванията се обработват от `rtl/measurement_controller.sv`, а условното управление и branch решенията се обработват от `rtl/feedback_unit.sv`.

Петото изискване е възможност за систематична симулационна проверка. За всеки основен модул е създаден Verilator testbench, а общият regression flow се изпълнява чрез `scripts/run_verilator.sh`.

Шестото изискване е начална проверка за синтезируемост. Поради ограниченията на наличния Yosys frontend е създаден отделен synthesis-friendly top-level файл: `rtl_synth/quantum_controller_top_synth.sv`.

### Таблица 2.1 – Системни изисквания и RTL покритие

| № | Изискване | Реализиращ модул | Testbench / проверка |
|---|---|---|---|
| 1 | Instruction-driven вход | `qc_pkg.sv`, `instruction_decoder.sv` | `tb_qc_pkg.sv`, `tb_instruction_decoder.sv` |
| 2 | Декодиране на инструкции | `instruction_decoder.sv` | `tb_instruction_decoder.sv` |
| 3 | Буфериране на операции | `operation_queue.sv` | `tb_operation_queue.sv` |
| 4 | Управление на зависимости | `dependency_tracker.sv` | `tb_dependency_tracker.sv` |
| 5 | Scheduling | `scheduler.sv` | `tb_scheduler.sv` |
| 6 | Цифров command интерфейс | `execution_controller.sv` | `tb_execution_controller.sv` |
| 7 | Управление на измервания | `measurement_controller.sv` | `tb_measurement_controller.sv` |
| 8 | Feedback/branch логика | `feedback_unit.sv` | `tb_feedback_unit.sv` |
| 9 | Top-level интеграция | `quantum_controller_top.sv` | `tb_quantum_controller_top.sv` |
| 10 | Synthesis smoke test | `quantum_controller_top_synth.sv` | `run_yosys_synth.sh` |

---

## 2.1.2 Дефиниране на instruction format

Instruction format-ът е централен елемент на архитектурата, защото определя начина, по който квантовите операции се представят пред контролера. В реализирания RTL модел се използва фиксирана 32-битова инструкция.

### Таблица 2.2 – 32-битов instruction format

| Битове | Поле | Ширина | Описание |
|---|---|---:|---|
| [31:28] | `opcode` | 4 бита | Тип на операцията |
| [27:24] | `target_qubit` | 4 бита | Целеви кубит |
| [23:20] | `control_qubit` | 4 бита | Контролен кубит при двукубитни операции |
| [19:8] | `duration` | 12 бита | Продължителност или branch target |
| [7:4] | `flags` | 4 бита | Валидност, условност, feedback и expected value |
| [3:0] | `reserved` | 4 бита | Резервирано поле |

Поддържаните opcode стойности са дефинирани в `rtl/qc_pkg.sv`. Основният набор от инструкции включва:

### Таблица 2.3 – Поддържани инструкции

| Инструкция | Opcode | Тип | Роля |
|---|---:|---|---|
| `NOP` | `4'h0` | контролна | Няма операция |
| `H` | `4'h1` | еднокубитна | Hadamard операция |
| `X` | `4'h2` | еднокубитна | Pauli-X операция |
| `Z` | `4'h3` | еднокубитна | Pauli-Z операция |
| `CNOT` | `4'h4` | двукубитна | Контролирана операция |
| `MEASURE` | `4'h5` | измерване | Заявка за измерване |
| `WAIT` | `4'h6` | времева | Изчакване |
| `RESET` | `4'h7` | контролна | Reset команда |
| `BRANCH` | `4'h8` | управляваща | Feedback/branch сценарий |

Полето `flags` се използва за валидност и условно управление. В текущата реализация то има следната логика:

| Бит | Значение |
|---|---|
| `flags[3]` | valid |
| `flags[2]` | conditional branch |
| `flags[1]` | feedback-related branch |
| `flags[0]` | expected measurement value |

Примерна инструкция:

```text
{4'h5, 4'd3, 4'd0, 12'd6, 4'b1000, 4'd0}
```

означава:

```text
MEASURE q3 с duration = 6 и valid flag = 1
```

---

## 2.1.3 Обхват, допускания и ограничения на RTL реализацията

Текущата RTL реализация е фокусирана върху цифровата контролна логика. Квантовият процесор се разглежда като абстрактен изпълнителен слой, към който контролерът подава команди. Поради това архитектурата не съдържа аналогов pulse generator и не генерира реални микровълнови или лазерни импулси.

Това ограничение е важно за коректното позициониране на дисертацията. В Глава 1 се разглеждат съществуващи системи, които често използват pulse-level управление, но реализираният контролер в тази работа се намира на по-високо цифрово инструкционно ниво. Той обработва инструкции и генерира command сигнали, които в бъдеща система биха могли да бъдат свързани с по-ниско ниво за генериране на физически импулси.

Текущата реализация също така не включва пълен out-of-order scheduler. Scheduler-ът е in-order dependency-aware. Това означава, че контролерът разглежда операцията в началото на опашката и я издава само когато няма hazard върху target или control кубита. Ако има зависимост, операцията изчаква.

Measurement резултатите се подават абстрактно чрез входни сигнали:

```text
measurement_result_valid_i
measurement_result_i
```

Контролерът не моделира вероятностната природа на квантовото измерване. Той само приема вече получен класически резултат и го съхранява във вътрешен measurement state.

---

## 2.1.4 Общ архитектурен модел

Общият архитектурен модел се състои от няколко последователни RTL блока.

```text
+-----------------------+
|  raw instruction_i    |
+----------+------------+
           |
           v
+-----------------------+
| instruction_decoder   |
+----------+------------+
           |
           v
+-----------------------+
| operation_queue       |
+----------+------------+
           |
           v
+-----------------------+
| scheduler             |
| + dependency_tracker  |
+----------+------------+
           |
           v
+-----------------------+
| execution_controller  |
+----------+------------+
           |
           +-------------------+
           |                   |
           v                   v
+-----------------------+   +----------------+
| measurement_controller|   | feedback_unit  |
+-----------------------+   +----------------+
```

Този модел осигурява разделение между декодиране, буфериране, проверка на зависимости, планиране, изпълнение, измерване и feedback логика.

---

# 2.2 Организация на RTL проекта и файловата структура

## 2.2.1 Директории и роля на основните файлове

Проектът е организиран в няколко основни директории:

| Директория | Роля |
|---|---|
| `rtl/` | Основна модулна SystemVerilog RTL реализация |
| `tb/` | Verilator testbench-и |
| `scripts/` | Скриптове за симулация и синтез |
| `rtl_synth/` | Yosys-friendly synthesis top |
| `results/simulation_logs/` | Simulation log файлове |
| `results/waveforms/` | VCD waveform файлове |
| `results/synthesis_reports/` | Yosys synthesis outputs |
| `docs/` | Документация, работни Markdown файлове и дисертационни документи |

---

## 2.2.2 Общ package и параметри на архитектурата (`qc_pkg.sv`)

Файлът `rtl/qc_pkg.sv` съдържа общите типове, параметри и opcode дефиниции. Той централизира архитектурните константи, така че отделните модули да използват еднакво представяне на инструкциите.

Тук трябва да се опишат:

- `INSTR_W`;
- `QUBIT_ID_W`;
- `DURATION_W`;
- `FLAGS_W`;
- `MAX_QUBITS`;
- `qc_opcode_e`;
- `qc_instr_fields_t`.

---

## 2.2.3 Тестова и simulation инфраструктура

Simulation flow-ът се базира на Verilator. Всеки основен модул има отделен testbench, а top-level интеграцията се проверява чрез `tb/tb_quantum_controller_top.sv`.

Regression script:

```text
scripts/run_verilator.sh
```

Той позволява изпълнение на единичен тест:

```bash
./scripts/run_verilator.sh tb_scheduler
```

или всички тестове:

```bash
./scripts/run_verilator.sh all
```

---

## 2.2.4 Synthesis-friendly RTL вариант

Поради ограниченията на наличния Yosys frontend е създаден отделен synthesis-friendly top:

```text
rtl_synth/quantum_controller_top_synth.sv
```

Този файл не заменя основната архитектура в `rtl/`. Той служи като първи synthesis smoke-test вариант.

---

# 2.3 Блокова архитектура на контролера

## 2.3.1 Top-level архитектура

Top-level интеграцията се намира във файла:

```text
rtl/quantum_controller_top.sv
```

Този модул свързва:

- instruction decoder;
- operation queue;
- scheduler;
- execution controller;
- measurement controller;
- feedback unit.

---

## 2.3.2 Основни RTL модули

| Модул | Файл | Основна функция |
|---|---|---|
| Instruction package | `rtl/qc_pkg.sv` | Общи типове и параметри |
| Instruction Decoder | `rtl/instruction_decoder.sv` | Декодира 32-битова инструкция |
| Operation Queue | `rtl/operation_queue.sv` | Буферира операции |
| Dependency Tracker | `rtl/dependency_tracker.sv` | Проверява qubit hazards |
| Scheduler | `rtl/scheduler.sv` | Издава операции към execution stage |
| Execution Controller | `rtl/execution_controller.sv` | Генерира command сигнали |
| Measurement Controller | `rtl/measurement_controller.sv` | Управлява MEASURE заявки и резултати |
| Feedback Unit | `rtl/feedback_unit.sv` | Обработва BRANCH/feedback |
| Top-level | `rtl/quantum_controller_top.sv` | Интегрира всички модули |

---

## 2.3.3 Поток на данни

Данните започват като 32-битова инструкция. След декодиране те се представят като вътрешна структура с полета за opcode, target/control qubit, duration и flags. Тази структура преминава през queue, scheduler и execution controller.

---

## 2.3.4 Контролен поток

Основните контролни сигнали са:

| Сигнал | Роля |
|---|---|
| `instr_valid_i` | Показва валидна входна инструкция |
| `instr_ready_o` | Показва, че контролерът може да приеме инструкция |
| `queue_pop_o` | Изваждане на операция от queue |
| `issue_valid_o` | Scheduler-ът издава операция |
| `command_valid_o` | Execution controller генерира валидна команда |
| `measure_request_valid_o` | Measurement controller заявява измерване |
| `feedback_valid_o` | Feedback unit е взел branch решение |

---

## 2.3.5 Интерфейси и изходни сигнали

Тук трябва да се опишат top-level портовете от `quantum_controller_top.sv`, включително:

- instruction input interface;
- command output interface;
- measurement result input;
- measurement output interface;
- feedback/branch outputs;
- debug/status outputs.

---

# 2.4 Математическа формализация на scheduler

## 2.4.1 Моделиране на квантова операция

Всяка операция може да бъде моделирана като:

```text
op = (opcode, target_qubit, control_qubit, duration, flags)
```

Това съответства на вътрешното представяне в `qc_instr_fields_t`.

---

## 2.4.2 Представяне чрез dependency graph / DAG

На теоретично ниво квантовата програма може да се представи като dependency graph, в който възлите са операции, а ребрата са зависимости между операции.

Важно уточнение: текущата RTL реализация не е пълен out-of-order DAG scheduler. Тя използва in-order dependency-aware модел, при който се проверява дали операцията в началото на опашката може да бъде издадена без конфликт.

---

## 2.4.3 Ресурсни ограничения и qubit busy модел

Всеки кубит се разглежда като ресурс. Ако върху даден кубит вече се изпълнява операция, следваща операция върху същия кубит трябва да изчака.

Scheduler-ът използва busy counter модел:

```text
busy_cnt_q[qubit] > 0 → qubit is busy
busy_cnt_q[qubit] = 0 → qubit is free
```

---

## 2.4.4 Критерий за latency и stall cycles

Основните метрики са:

- latency;
- stall cycles;
- issued operations per cycle;
- queue occupancy;
- measurement latency;
- feedback latency.

---

## 2.4.5 Реализиран dependency-aware scheduling алгоритъм

Реализираният алгоритъм е:

```text
1. Вземи операцията от началото на operation_queue.
2. Определи кои кубити използва операцията.
3. Провери дали target/control кубитите са busy.
4. Ако няма hazard → issue operation.
5. Ако има hazard → stall.
6. При issue маркирай използваните кубити като busy за duration цикли.
```

Свързани файлове:

```text
rtl/dependency_tracker.sv
rtl/scheduler.sv
tb/tb_dependency_tracker.sv
tb/tb_scheduler.sv
```

---

## 2.4.6 Анализ на сложността и ограничения на текущата реализация

Текущата реализация е проста, ясна и подходяща за RTL демонстрация, но има ограничения:

- in-order issue;
- няма reorder buffer;
- няма пълен DAG traversal;
- няма parallel multi-issue;
- dependency model-ът е базиран основно на target/control qubit busy state.

---

# 2.5 RTL имплементация на основните модули

## 2.5.1 Instruction package и instruction format (`qc_pkg.sv`)

Да се опишат типовете и параметрите от `rtl/qc_pkg.sv`.

## 2.5.2 Instruction Decoder (`instruction_decoder.sv`)

Да се опише декодирането на 32-битовата инструкция и illegal opcode handling.

## 2.5.3 Operation Queue (`operation_queue.sv`)

Да се опише FIFO поведението, push/pop логиката, full/empty/count сигналите.

## 2.5.4 Dependency Tracker (`dependency_tracker.sv`)

Да се опише как се определят използваните кубити и dependency hazard.

## 2.5.5 Scheduler (`scheduler.sv`)

Да се опише връзката между scheduler, dependency tracker и busy counters.

## 2.5.6 Execution Controller и цифров command интерфейс (`execution_controller.sv`)

Важно: тук да не се използва терминът Pulse Generator като реализиран модул. Реализиран е цифров command интерфейс, не аналогов pulse генератор.

Да се опишат:

- `command_valid_o`;
- `gate_cmd_o`;
- `measure_cmd_o`;
- `wait_cmd_o`;
- `reset_cmd_o`;
- `branch_cmd_o`;
- `nop_cmd_o`;
- `illegal_issue_o`.

## 2.5.7 Measurement Controller (`measurement_controller.sv`)

Да се опишат:

- `measure_request_valid_o`;
- `measure_qubit_o`;
- `measurement_busy_o`;
- `measurement_result_valid_i`;
- `measurement_result_i`;
- съхранение на measurement резултати.

## 2.5.8 Feedback Unit (`feedback_unit.sv`)

Да се опишат:

- conditional branch;
- expected measurement value;
- missing measurement;
- branch taken;
- branch target.

## 2.5.9 Top-level интеграция (`quantum_controller_top.sv`)

Да се опише full pipeline integration.

---

# 2.6 FSM и вътрешни контролни състояния

## 2.6.1 Queue и scheduler поведение

Да се опише взаимодействието между queue empty/full/count и scheduler issue/stall.

## 2.6.2 Busy-counter модел за кубити

Да се опише как всеки кубит има counter, който се намалява всеки такт.

## 2.6.3 Measurement pending logic

Да се опише pending състоянието в measurement controller.

## 2.6.4 Feedback/branch decision logic

Да се опише как feedback unit взема branch решение.

---

# 2.7 Pipeline архитектура и end-to-end изпълнение

## 2.7.1 Път на инструкцията през контролера

Да се опише пълният път от `instr_i` до output командите.

## 2.7.2 Gate/measure/wait/reset/branch командни сценарии

Да се опишат отделни сценарии за различните opcode-и.

## 2.7.3 End-to-end MEASURE → result → BRANCH сценарий

Да се опише ключовият интеграционен сценарий:

```text
MEASURE q3
→ measurement_result_i = 1
→ BRANCH if q3 == 1
→ branch_taken_o = 1
```

## 2.7.4 Ограничения на текущия in-order pipeline

Да се опишат ограниченията спрямо бъдещ out-of-order или multi-issue pipeline.

---

# 2.8 Verilator симулационна проверка на RTL

## 2.8.1 Module-level testbench-и

Да се опише кои testbench-и съществуват и какво проверяват.

## 2.8.2 Top-level integration testbench

Основен файл:

```text
tb/tb_quantum_controller_top.sv
```

## 2.8.3 Regression script и simulation logs

Основен script:

```text
scripts/run_verilator.sh
```

Команда:

```bash
./scripts/run_verilator.sh all
```

## 2.8.4 Waveform файлове и проследимост към RTL

Да се опишат VCD файловете в:

```text
results/waveforms/
```

---

# 2.9 Синтезируемост и Yosys-friendly synthesis flow

## 2.9.1 Синтезируем SystemVerilog subset

Да се опише, че основният RTL е написан като синтезируем SystemVerilog, но използва package/typedef/struct конструкции, които са удобни за Verilator и UVM.

## 2.9.2 Причина за отделен `rtl_synth` вариант

Да се обясни:

- наличният Yosys няма `read_slang`;
- липсва `sv2v`;
- default frontend се затруднява с package/typedef/struct;
- затова е създаден synthesis-friendly top.

## 2.9.3 `quantum_controller_top_synth.sv`

Да се опише ролята на:

```text
rtl_synth/quantum_controller_top_synth.sv
```

Той е smoke-test synthesis вариант, не заместител на основния RTL.

## 2.9.4 Yosys scripts и synthesis reports

Да се посочат:

```text
scripts/synth_quantum_controller_top.ys
scripts/run_yosys_synth.sh
results/synthesis_reports/quantum_controller_top_synth_yosys.log
results/synthesis_reports/quantum_controller_top_synth.json
```

## 2.9.5 Ограничения и бъдещо подобрение на synthesis flow

Да се опише, че бъдещо подобрение може да включва:

- инсталация на `read_slang`;
- използване на `sv2v`;
- refactor на основния RTL към по-Yosys-friendly subset;
- директен синтез на модулната RTL архитектура.

---

# 2.10 Обобщение на реализираната RTL архитектура

## 2.10.1 Проследимост между изисквания, модули и тестове

Да се включи таблица:

| Изискване | RTL модул | Testbench | Резултат |
|---|---|---|---|

## 2.10.2 Ограничения на текущата реализация

Да се посочат:

- няма физически quantum processor;
- няма analog pulse generation;
- scheduler е in-order dependency-aware;
- няма multi-issue;
- Yosys synthesis използва отделен synthesis-friendly top.

## 2.10.3 Подготовка за UVM верификация

Да се направи преход към Глава 3:

- DUT интерфейси;
- наблюдаеми сигнали;
- directed tests;
- constrained random tests;
- algorithmic workloads;
- coverage model.
