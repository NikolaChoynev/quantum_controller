# ГЛАВА 2: RTL архитектура на квантовия контролер

# 2.1 Архитектурна концепция

След формулирането на научния проблем и анализа на съществуващите подходи за управление на квантови системи настоящата глава представя реализираната RTL архитектура на класически контролер за квантови операции. За разлика от теоретичния обзор в Глава 1, тук фокусът е върху конкретната цифрова реализация, разработените SystemVerilog модули, вътрешния поток на данни, управляващите състояния и доказателствата за функционална коректност, получени чрез симулация.

За да се запази проследимостта между дисертационния текст и реалната инженерна реализация, описанието в тази глава използва не само фигури и таблици, а и преки препратки към конкретните RTL файлове, testbench-и, simulation logs и synthesis reports. Това означава, че всяко съществено архитектурно твърдение трябва да може да бъде свързано с реален артефакт от проекта, например `rtl/scheduler.sv`, `tb/tb_scheduler.sv`, `results/simulation_logs/tb_scheduler.log` или `results/synthesis_reports/quantum_controller_top_synth_yosys.log`.

Освен имената на файловете, финалният текст трябва да включва и кратки реални кодови фрагменти от RTL имплементацията, когато те доказват важна архитектурна логика. Такива фрагменти не трябва да заменят обяснението, а да го подкрепят. Подходящи примери са условието за issue в scheduler-а, flush логиката на operation queue, flag дефинициите в package файла, measurement pending състоянието и branch decision логиката във feedback unit-а. Фигурите и таблиците служат за обобщение и визуализация, но не заменят нито препратките към кода, нито кратките реални RTL откъси.

Основната идея на архитектурата е да се реализира instruction-driven контролен слой, при който квантовите операции се представят чрез фиксирани цифрови инструкции. Всяка инструкция съдържа код на операцията, идентификатори на участващите кубити, поле за продължителност и управляващи флагове. След постъпване във входния интерфейс инструкцията се декодира, буферира, проверява за зависимости, планира се за изпълнение и се преобразува в цифрови command сигнали към абстрактен квантов изпълнителен слой.

Реализираният контролер е класическа цифрова RTL система. Той не моделира физическото квантово устройство, не генерира аналогови импулси, не симулира шум, декохерентност или конкретна технология за физически кубити. Тези нива остават извън обхвата на разработката. Обект на реализацията е логическият контролен механизъм, който управлява реда на квантовите операции, зависимостите между тях, заявките за измерване и базовата feedback/branch логика.

Архитектурата е реализирана като модулна SystemVerilog RTL система. Основните функционални блокове са `instruction_decoder`, `operation_queue`, `dependency_tracker`, `scheduler`, `execution_controller`, `measurement_controller`, `feedback_unit` и top-level интеграционният модул `quantum_controller_top`. Всеки от тези блокове има отделна роля в обработката на инструкциите и е покрит от самостоятелен или интеграционен Verilator testbench.

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

Тази последователност от блокове позволява ясно разделение между декодиране, буфериране, dependency-aware scheduling, генериране на цифрови команди, обработка на measurement резултати и вземане на feedback/branch решения. По този начин архитектурата осигурява проследимост между входната инструкция, вътрешното RTL представяне и наблюдаемите изходни сигнали на контролера.

---

## 2.1.1 Системни изисквания

Реализираният контролер е разработен според набор от системни изисквания, които определят както архитектурния модел, така и границите на RTL реализацията. Първото изискване е поддръжката на instruction-driven управление. Входът на системата се представя като последователност от 32-битови инструкции, а не като директни физически импулси или аналогови управляващи форми. Този подход позволява квантовите операции да бъдат обработвани от хардуерна логика чрез формализиран формат.

Второто изискване е наличието на ясен механизъм за декодиране на инструкциите. В реализирания RTL модел `rtl/instruction_decoder.sv` извлича от входната дума полетата `opcode`, `target_qubit`, `control_qubit`, `duration` и `flags`, като едновременно с това генерира индикация за валидност и illegal opcode състояние. Валидността на инструкцията се определя чрез `flags[3]`, дефиниран като `FLAG_VALID_BIT` в `rtl/qc_pkg.sv`.

Третото изискване е управление на зависимости между операции върху едни и същи кубити. Ако даден кубит е зает от текущо изпълнявана операция, следваща операция, която използва същия кубит, не трябва да бъде издавана, докато ресурсът не бъде освободен. Това поведение се реализира чрез комбинацията от `rtl/dependency_tracker.sv` и `rtl/scheduler.sv`, където dependency tracker-ът определя използваните кубити, а scheduler-ът поддържа busy-counter модел.

Четвъртото изискване е поддръжка на операции за измерване и feedback управление. Measurement логиката се реализира в `rtl/measurement_controller.sv`, който генерира заявка за измерване, пази pending състояние и съхранява резултатите по кубити. Feedback логиката се реализира в `rtl/feedback_unit.sv`, който обработва branch операции на базата на вече налични measurement резултати.

Петото изискване е top-level интеграция с контрол на backpressure и control-flow hazards. В `rtl/quantum_controller_top.sv` са интегрирани сигналите за queue full/empty, scheduler stall, measurement busy, branch in-flight състояние и flush на operation queue при taken branch. Това гарантира, че по-млади инструкции не се изпълняват неправилно след взето разклонение и че не се издава ново измерване, докато предходното измерване е pending.

Шестото изискване е възможност за систематична функционална проверка. За всеки основен RTL модул е разработен Verilator testbench, а общият regression flow се изпълнява чрез `scripts/run_verilator.sh`. Интеграционният testbench `tb/tb_quantum_controller_top.sv` проверява end-to-end сценарии, включително measurement-feedback поведение, measurement backpressure и branch flush.

Седмото изискване е начална проверка за синтезируемост. Поради ограниченията на наличния Yosys SystemVerilog frontend е създаден отделен synthesis-friendly top-level файл `rtl_synth/quantum_controller_top_synth.sv`, който се използва за първоначален synthesis smoke test чрез `scripts/run_yosys_synth.sh`. Този файл не заменя основната модулна RTL архитектура, а служи като практичен вариант за проверка със съществуващия synthesis flow.

### Таблица 2.1 – Системни изисквания и RTL покритие

| № | Изискване | Реализиращ модул | Testbench / проверка |
|---|---|---|---|
| 1 | Instruction-driven вход | `qc_pkg.sv`, `instruction_decoder.sv` | `tb_qc_pkg.sv`, `tb_instruction_decoder.sv` |
| 2 | Декодиране на инструкции | `instruction_decoder.sv` | `tb_instruction_decoder.sv` |
| 3 | Буфериране на операции | `operation_queue.sv` | `tb_operation_queue.sv` |
| 4 | Управление на зависимости | `dependency_tracker.sv` | `tb_dependency_tracker.sv` |
| 5 | Dependency-aware scheduling | `scheduler.sv` | `tb_scheduler.sv` |
| 6 | Цифров command интерфейс | `execution_controller.sv` | `tb_execution_controller.sv` |
| 7 | Управление на измервания | `measurement_controller.sv` | `tb_measurement_controller.sv` |
| 8 | Feedback/branch логика | `feedback_unit.sv` | `tb_feedback_unit.sv` |
| 9 | Top-level интеграция | `quantum_controller_top.sv` | `tb_quantum_controller_top.sv` |
| 10 | Control-flow hazard handling | `operation_queue.sv`, `scheduler.sv`, `quantum_controller_top.sv` | `tb_operation_queue.sv`, `tb_scheduler.sv`, `tb_quantum_controller_top.sv` |
| 11 | Synthesis smoke test | `quantum_controller_top_synth.sv` | `run_yosys_synth.sh` |

---

## 2.1.2 Дефиниране на instruction format

Instruction format-ът е централен елемент на архитектурата, защото определя начина, по който квантовите операции се представят пред контролера. В реализирания RTL модел се използва фиксирана 32-битова инструкция, дефинирана в `rtl/qc_pkg.sv`. Фиксираният формат опростява декодирането и позволява всички основни полета да бъдат извлечени чрез структурно RTL представяне.

Всяка инструкция съдържа opcode поле, идентификатор на целеви кубит, идентификатор на контролен кубит, поле за продължителност, управляващи флагове и резервирано поле. Полето `duration` се използва като продължителност за операции като gate и wait, а при branch операция се използва като branch target в реализирания feedback модел.

### Таблица 2.2 – 32-битов instruction format

| Битове | Поле | Ширина | Описание |
|---|---|---:|---|
| [31:28] | `opcode` | 4 бита | Тип на операцията |
| [27:24] | `target_qubit` | 4 бита | Целеви кубит |
| [23:20] | `control_qubit` | 4 бита | Контролен кубит при двукубитни операции |
| [19:8] | `duration` | 12 бита | Продължителност или branch target |
| [7:4] | `flags` | 4 бита | Валидност, условност, feedback и expected value |
| [3:0] | `reserved` | 4 бита | Резервирано поле |

Поддържаните opcode стойности са дефинирани чрез enum типа `qc_opcode_e` в `rtl/qc_pkg.sv`. Основният набор от инструкции включва еднокубитни операции, двукубитна контролирана операция, измерване, изчакване, reset, branch и invalid код за обработка на неправилни opcode стойности.

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
| `INVALID` | `4'hF` | диагностична | Невалидна операция |

Полето `flags` се използва за валидност и условно управление. В текущата реализация то има следната логика:

### Таблица 2.4 – Управляващи флагове

| Бит | Константа | Значение |
|---|---|---|
| `flags[3]` | `FLAG_VALID_BIT` | Валидна инструкция |
| `flags[2]` | `FLAG_CONDITIONAL_BIT` | Условен branch |
| `flags[1]` | `FLAG_FEEDBACK_BIT` | Feedback-related branch |
| `flags[0]` | `FLAG_EXPECTED_BIT` | Очаквана measurement стойност |

Примерна инструкция:

```text
{4'h5, 4'd3, 4'd0, 12'd6, 4'b1000, 4'd0}
```

означава:

```text
MEASURE q3 с duration = 6 и valid flag = 1
```

След декодиране тази инструкция се представя чрез структурата `qc_instr_fields_t`, която съдържа същите полета в типизиран вид. Използването на общ package файл намалява риска от несъответствие между отделните RTL модули, защото opcode стойностите, ширините на полетата и флаговете се дефинират централизирано.

---

## 2.1.3 Обхват, допускания и ограничения на RTL реализацията

Обхватът на RTL реализацията е ограничен до цифровата контролна логика на instruction-driven квантов контролер. Квантовият процесор се разглежда като абстрактен изпълнителен слой, към който контролерът подава команди. Следователно архитектурата не съдържа аналогов pulse generator, не генерира реални микровълнови или лазерни импулси и не моделира физическите процеси, чрез които се въздейства върху конкретни кубити.

Това ограничение е съществено за правилното позициониране на разработката. В съвременните квантови системи контролният стек често включва няколко нива: компилаторен слой, логически контролен слой, pulse-level слой и физически quantum backend. Реализираният в тази работа контролер се намира на цифровото инструкционно ниво. Той приема формализирани инструкции и генерира цифрови command сигнали, които в бъдеща пълна система могат да бъдат свързани с по-ниско ниво за pulse generation.

Scheduler-ът в текущата реализация е in-order dependency-aware scheduler. Той не реализира пълен out-of-order DAG traversal, reorder buffer или multi-issue изпълнение. Контролерът разглежда операцията в началото на operation queue и я издава само ако няма dependency hazard, downstream логиката е готова и няма активен WAIT hold. Това решение намалява сложността на първоначалния RTL модел и позволява ясно функционално тестване на dependency, stall и busy-counter поведението.

Measurement резултатите се подават абстрактно чрез входни сигнали:

```text
measurement_result_valid_i
measurement_result_i
```

Контролерът не моделира вероятностната природа на квантовото измерване. Той приема вече получен класически резултат, свързва го с pending measurement операцията и го съхранява във вътрешни регистри по кубити. На тази база feedback unit модулът може да провери условие за branch операция.

Реализацията съдържа базова control-flow защита. Докато measurement операция е pending, top-level логиката не допуска издаване на следваща `MEASURE` команда. Докато branch операция е in-flight, не се издава нов branch. При taken branch operation queue се flush-ва, така че инструкциите, които вече са били буферирани след branch-а, да не продължат неправилно към изпълнение.

Началният synthesis flow също има ясно ограничение. Основната модулна реализация в `rtl/` се използва за Verilator симулации и като база за бъдеща UVM среда. Поради ограниченията на наличния Yosys frontend първият synthesis smoke test се изпълнява върху отделния файл `rtl_synth/quantum_controller_top_synth.sv`. Това разграничение трябва да се запази и в анализа на резултатите.

---

## 2.1.4 Общ архитектурен модел

Общият архитектурен модел се състои от последователно свързани RTL блокове, като всеки блок изпълнява отделна функция от пътя на инструкцията. На входа на системата постъпва 32-битова инструкция, която се декодира и преобразува във вътрешно структурирано представяне. След това инструкцията се записва в operation queue, откъдето scheduler-ът я разглежда за издаване.

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

Scheduler-ът използва dependency tracker и вътрешни busy counters, за да определи дали операцията може да бъде издадена. Ако операцията е независима и downstream логиката е готова, тя се подава към execution controller. Execution controller-ът класифицира операцията като gate, measure, wait, reset, branch или nop команда и генерира съответните цифрови output сигнали.

Measurement controller-ът обработва `MEASURE` командите, генерира measurement request и съхранява получените measurement резултати. Feedback unit модулът използва тези резултати при branch операции, като проверява дали измерената стойност съвпада с очакваната стойност от instruction flags. Ако условието е изпълнено, се активира `branch_taken_o`, а top-level логиката flush-ва operation queue.

Top-level модулът `rtl/quantum_controller_top.sv` координира целия поток. Той свързва отделните RTL блокове, генерира `instr_ready_o`, управлява push/pop поведението на queue-а, подава readiness към scheduler-а и изнася debug/status сигнали като `queue_count_o`, `qubit_busy_o`, `scheduler_stall_o`, `illegal_instr_o` и `illegal_issue_o`. По този начин top-level модулът служи като интеграционна точка между instruction входа, execution командите, measurement интерфейса и feedback/branch изходите.

---

# 2.2 Организация на RTL проекта и файловата структура

## 2.2.1 Директории и роля на основните файлове

Проектът е организиран така, че да осигури проследимост между RTL реализацията, тестовата инфраструктура, synthesis flow-а и дисертационната документация. Основната SystemVerilog реализация се намира в директорията `rtl/`, а testbench-ите са отделени в `tb/`. Скриптовете за автоматизирано стартиране на симулации и синтез са в `scripts/`, докато резултатите от симулации, waveform файлове и synthesis reports се съхраняват в `results/`.

Тази организация позволява всяко твърдение в Глава 2 да бъде свързано с конкретен файл или артефакт. Например описанието на instruction format-а се свързва с `rtl/qc_pkg.sv`, поведението на scheduler-а се свързва с `rtl/scheduler.sv` и `tb/tb_scheduler.sv`, а началният synthesis flow се свързва с `rtl_synth/quantum_controller_top_synth.sv` и `results/synthesis_reports/quantum_controller_top_synth_yosys.log`.

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

Файлът `rtl/qc_pkg.sv` съдържа общите типове, параметри и opcode дефиниции на архитектурата. Той е централна точка за описание на instruction format-а и гарантира, че всички RTL модули използват еднакви ширини на полета, еднакви opcode стойности и еднакво тълкуване на управляващите флагове.

В package файла са дефинирани основните архитектурни параметри:

| Параметър | Стойност | Роля |
|---|---:|---|
| `INSTR_W` | 32 | Ширина на входната инструкция |
| `OPCODE_W` | 4 | Ширина на opcode полето |
| `QUBIT_ID_W` | 4 | Ширина на qubit identifier полетата |
| `DURATION_W` | 12 | Ширина на duration/branch target полето |
| `FLAGS_W` | 4 | Ширина на flags полето |
| `RESERVED_W` | 4 | Ширина на reserved полето |
| `MAX_QUBITS` | 16 | Максимален брой адресируеми логически кубити |

Освен параметрите, package файлът дефинира `qc_opcode_e`, `qc_flags_t`, `qc_instr_fields_t` и `qc_instr_t`. Структурата `qc_instr_fields_t` описва декодираното представяне на инструкцията, а union типът `qc_instr_t` позволява една и съща 32-битова дума да бъде разглеждана както като raw стойност, така и като структурирани полета. Това е удобно за instruction decoder модула и намалява нуждата от ръчно разместване на битови полета в отделни части на проекта.

---

## 2.2.3 Тестова и simulation инфраструктура

Simulation flow-ът се базира на Verilator. Всеки основен RTL модул има отделен testbench, а top-level интеграцията се проверява чрез `tb/tb_quantum_controller_top.sv`. Този подход позволява първо да се валидира локалното поведение на отделните блокове, а след това да се провери end-to-end пътят на инструкцията през целия контролер.

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

Наличните simulation logs са записани в `results/simulation_logs/`, а waveform файловете са в `results/waveforms/`. Последният regression run потвърждава успешно изпълнение на module-level тестовете за package, decoder, queue, dependency tracker, scheduler, execution controller, measurement controller и feedback unit, както и на top-level integration testbench-а. Важни сценарии, покрити от тестовете, са FIFO push/pop/full/flush поведение, dependency hazard detection, scheduler stall при backpressure, WAIT hold, measurement result storage, unexpected measurement result, conditional branch, unconditional branch и taken branch flush.

---

## 2.2.4 Synthesis-friendly RTL вариант

Поради ограниченията на наличния Yosys frontend е създаден отделен synthesis-friendly top:

```text
rtl_synth/quantum_controller_top_synth.sv
```

Този файл не заменя основната архитектура в `rtl/`. Той служи като първи synthesis smoke-test вариант, адаптиран към поддържания от наличната Yosys инсталация SystemVerilog subset. Причината за това разделение е, че основната RTL реализация използва package, typedef, enum, struct и union конструкции, които са удобни за Verilator симулация и бъдеща UVM верификация, но не се обработват директно от използвания Yosys frontend.

Synthesis flow-ът се стартира чрез:

```bash
./scripts/run_yosys_synth.sh
```

Резултатите се записват в:

```text
results/synthesis_reports/quantum_controller_top_synth_yosys.log
results/synthesis_reports/quantum_controller_top_synth.json
```

Последният synthesis run завършва успешно и генерира JSON netlist. В log файла са отчетени две очаквани предупреждения за замяна на вътрешни памети с регистри. Тези предупреждения са приемливи за текущия smoke-test flow и трябва да бъдат описани като ограничение на началната synthesis проверка, а не като функционална грешка в основния RTL модел.

---

# 2.3 Блокова архитектура на контролера

## 2.3.1 Top-level архитектура

Top-level интеграцията на контролера се реализира във файла:

```text
rtl/quantum_controller_top.sv
```

Модулът `quantum_controller_top` представлява интеграционната точка между входния instruction интерфейс, вътрешния pipeline за обработка на операции, measurement интерфейса и feedback/branch изходите. Той инстанцира основните RTL блокове и управлява сигналите, които определят кога може да бъде приета нова инструкция, кога операцията може да бъде издадена от scheduler-а и кога operation queue трябва да бъде изчистена поради taken branch.

Top-level модулът е параметризиран чрез `QUEUE_DEPTH` и `NUM_QUBITS`. Параметърът `QUEUE_DEPTH` определя дълбочината на operation queue, а `NUM_QUBITS` определя броя на логическите кубити, за които се поддържат busy counters и measurement result регистри. По подразбиране `NUM_QUBITS` използва `MAX_QUBITS`, дефиниран в `rtl/qc_pkg.sv`.

Входният интерфейс приема 32-битовата инструкция чрез `instr_i`, валидира я чрез `instr_valid_i` и връща готовност чрез `instr_ready_o`. Готовността зависи от състоянието на queue-а и от control-flow събития като branch flush. Ако queue-ът е пълен или ако в текущия цикъл се извършва flush след taken branch, `instr_ready_o` не позволява приемане на нова инструкция.

След декодиране валидните и нелегални инструкции се обработват различно. Валидна инструкция с допустим opcode се записва в operation queue. Невалиден opcode не се записва, а top-level логиката активира `illegal_instr_o`. По този начин грешката се изнася като наблюдаем диагностичен сигнал, без да замърсява вътрешния pipeline.

Top-level модулът свързва следните функционални блокове:

| Блок | RTL модул | Роля в top-level архитектурата |
|---|---|---|
| Instruction decoder | `instruction_decoder` | Извлича полетата от 32-битовата инструкция |
| Operation queue | `operation_queue` | Буферира валидните инструкции до издаване |
| Scheduler | `scheduler` | Проверява dependencies, WAIT hold и downstream readiness |
| Execution controller | `execution_controller` | Преобразува issued операцията в цифров command интерфейс |
| Measurement controller | `measurement_controller` | Управлява measurement request и measurement result state |
| Feedback unit | `feedback_unit` | Проверява branch условия и генерира branch decision |

---

## 2.3.2 Основни RTL модули

Блоковата архитектура е изградена от малки RTL модули с ясно разделени отговорности. Това улеснява самостоятелното тестване на всеки модул, намалява сложността на top-level логиката и създава подходяща основа за бъдеща UVM верификационна среда. Всеки модул има собствен testbench или е проверен чрез top-level integration testbench.

| Модул | Файл | Основна функция | Проверка |
|---|---|---|
| Instruction package | `rtl/qc_pkg.sv` | Общи типове, параметри, opcode и flags дефиниции | `tb/tb_qc_pkg.sv` |
| Instruction Decoder | `rtl/instruction_decoder.sv` | Декодира 32-битова инструкция и маркира illegal opcode | `tb/tb_instruction_decoder.sv` |
| Operation Queue | `rtl/operation_queue.sv` | Буферира операции и поддържа flush при taken branch | `tb/tb_operation_queue.sv` |
| Dependency Tracker | `rtl/dependency_tracker.sv` | Определя използваните кубити и dependency hazards | `tb/tb_dependency_tracker.sv` |
| Scheduler | `rtl/scheduler.sv` | Издава операции при липса на hazard, backpressure и WAIT hold | `tb/tb_scheduler.sv` |
| Execution Controller | `rtl/execution_controller.sv` | Генерира command сигнали за gate, measure, wait, reset и branch | `tb/tb_execution_controller.sv` |
| Measurement Controller | `rtl/measurement_controller.sv` | Управлява MEASURE заявки, pending състояние и резултати | `tb/tb_measurement_controller.sv` |
| Feedback Unit | `rtl/feedback_unit.sv` | Обработва conditional/unconditional BRANCH решения | `tb/tb_feedback_unit.sv` |
| Top-level | `rtl/quantum_controller_top.sv` | Интегрира всички модули и control-flow backpressure логиката | `tb/tb_quantum_controller_top.sv` |

Това разделение е важно, защото позволява всяка архитектурна функция да бъде разгледана както като самостоятелен RTL блок, така и като част от общия път на инструкцията. Например `operation_queue.sv` може да бъде проверен като FIFO структура чрез push/pop/full/flush сценарии, но неговото поведение има значение и в top-level контекста, където flush се активира от `feedback_valid_o` и `branch_taken_o`.

---

## 2.3.3 Поток на данни

Потокът на данни започва от входната 32-битова инструкция `instr_i`. Тя се подава към `instruction_decoder`, където се извличат полетата `opcode`, `target_qubit`, `control_qubit`, `duration` и `flags`. След декодиране тези полета се записват във вътрешна структура от тип `qc_instr_fields_t`, която се използва като общо представяне на операцията в следващите етапи.

Ако инструкцията е валидна и opcode-ът е допустим, top-level логиката активира `queue_push` и записва операцията в `operation_queue`. Queue-ът съхранява декодираните инструкции в реда на постъпването им. На изхода на queue-а се намира операцията, която scheduler-ът разглежда за издаване. Този модел съответства на in-order pipeline, при който операцията в началото на queue-а блокира следващите операции, ако има dependency hazard или downstream backpressure.

Scheduler-ът получава операцията от `operation_queue`, проверява я чрез `dependency_tracker` и, ако условията позволяват, активира `issue_valid_o`. Издадената операция се подава към `execution_controller`, който генерира `command_valid_o`, `command_opcode_o`, `command_target_qubit_o`, `command_control_qubit_o`, `command_duration_o` и `command_flags_o`. Допълнително се активира един от командните класификатори: `gate_cmd_o`, `measure_cmd_o`, `wait_cmd_o`, `reset_cmd_o`, `branch_cmd_o` или `nop_cmd_o`.

При `MEASURE` операция command информацията се използва от `measurement_controller`, който генерира `measure_request_valid_o` и `measure_qubit_o`. Когато външният measurement резултат пристигне чрез `measurement_result_valid_i` и `measurement_result_i`, той се записва във вътрешните measurement result регистри. При `BRANCH` операция `feedback_unit` използва тези регистри, за да определи дали branch условието е изпълнено.

Данните за branch решението се изнасят чрез `feedback_valid_o`, `branch_taken_o`, `branch_target_o`, `feedback_qubit_o` и `feedback_value_o`. Ако branch е taken, top-level модулът активира queue flush, което премахва вече буферираните по-млади инструкции. Така data flow и control flow логиката се свързват в единен end-to-end pipeline.

---

## 2.3.4 Контролен поток

Контролният поток се определя от няколко групи сигнали. Първата група управлява приемането на инструкции. `instr_valid_i` показва, че на входа има валидна instruction дума, а `instr_ready_o` показва дали контролерът може да я приеме. Инструкция се записва в queue-а само ако едновременно са изпълнени условията за валидност, готовност, допустим opcode и липса на flush събитие.

Втората група сигнали управлява движението между operation queue и scheduler. `queue_pop_o` се активира, когато scheduler-ът може да издаде операцията в началото на queue-а. Scheduler-ът издава операция само ако dependency tracker-ът я маркира като независима, `issue_ready_i` е активен и няма активен WAIT hold. Ако има hazard, активен WAIT или downstream backpressure, `scheduler_stall_o` се активира.

Третата група контролни сигнали се отнася до command stage-а. `issue_valid_o` показва, че scheduler-ът е издал операция, а `command_valid_o` показва, че execution controller-ът е генерирал валидна команда. Командните one-hot-like сигнали класифицират типа на операцията и позволяват measurement и feedback блоковете да реагират само на съответните opcode сценарии.

Четвъртата група е свързана с measurement и feedback control-flow. `measurement_busy_o` показва, че има pending measurement операция. Докато този сигнал е активен, top-level логиката не допуска издаване на нова `MEASURE` операция. За branch операциите се използва вътрешно `branch_inflight_q` състояние, което блокира нов branch до получаване на `feedback_valid_o`. Ако `feedback_valid_o` и `branch_taken_o` са активни едновременно, се генерира queue flush.

Основните контролни сигнали са обобщени в следващата таблица.

| Сигнал | Роля |
|---|---|
| `instr_valid_i` | Показва валидна входна инструкция |
| `instr_ready_o` | Показва, че контролерът може да приеме инструкция |
| `queue_pop_o` | Изваждане на операция от queue |
| `issue_valid_o` | Scheduler-ът издава операция |
| `command_valid_o` | Execution controller генерира валидна команда |
| `measure_request_valid_o` | Measurement controller заявява измерване |
| `feedback_valid_o` | Feedback unit е взел branch решение |
| `branch_taken_o` | Feedback unit е определил, че branch трябва да се изпълни |
| `scheduler_stall_o` | Scheduler-ът не може да издаде текущата операция |
| `measurement_busy_o` | Има pending measurement операция |

---

## 2.3.5 Интерфейси и изходни сигнали

Top-level интерфейсите на контролера могат да бъдат разделени на шест групи: instruction input interface, issue/debug interface, command output interface, measurement interface, feedback/branch interface и status/error interface.

Instruction input interface-ът включва `instr_i`, `instr_valid_i` и `instr_ready_o`. Той реализира проста ready/valid схема за приемане на входни инструкции. Тази схема позволява контролерът да забави приемането на нова инструкция, когато queue-ът е пълен или когато се извършва control-flow flush.

Issue/debug interface-ът изнася информация за операцията, която scheduler-ът е издал. Той включва `issue_valid_o`, `issue_opcode_o`, `issue_target_qubit_o`, `issue_control_qubit_o`, `issue_duration_o` и `issue_flags_o`. Тези сигнали са полезни както за debug, така и за бъдеща верификационна среда, защото позволяват директно наблюдение на scheduler поведението.

Command output interface-ът описва операцията след execution controller stage-а. Той включва `command_valid_o`, `command_opcode_o`, `command_target_qubit_o`, `command_control_qubit_o`, `command_duration_o`, `command_flags_o` и командните класификатори `gate_cmd_o`, `measure_cmd_o`, `wait_cmd_o`, `reset_cmd_o`, `branch_cmd_o` и `nop_cmd_o`. Тези сигнали са цифровото представяне на командите, които в бъдеща разширена система могат да бъдат подадени към по-ниско ниво на изпълнение.

Measurement interface-ът включва входните сигнали `measurement_result_valid_i` и `measurement_result_i`, както и изходите `measure_request_valid_o`, `measure_qubit_o`, `measurement_busy_o`, `measurement_result_out_valid_o`, `measurement_result_qubit_o`, `measurement_result_value_o`, `measurement_valid_o`, `measurement_results_o` и `unexpected_measurement_result_o`. Този интерфейс отделя заявката за измерване от получаването на резултат, което позволява моделиране на latency между команда и measurement feedback.

Feedback/branch interface-ът включва `feedback_valid_o`, `branch_taken_o`, `branch_target_o`, `feedback_qubit_o`, `feedback_value_o`, `condition_checked_o` и `missing_measurement_o`. Чрез тези сигнали може да се наблюдава дали branch операцията е обработена, дали условието е проверено, дали има липсващ measurement резултат и каква е взетата control-flow посока.

Status/error interface-ът включва `scheduler_stall_o`, `illegal_instr_o`, `illegal_issue_o`, `queue_count_o` и `qubit_busy_o`. Тези сигнали са важни за симулации, waveform анализ и бъдеща UVM scoreboard логика, защото дават видимост върху вътрешното състояние на queue-а, scheduler-а и dependency модела.

---

# 2.4 Математическа формализация на scheduler

## 2.4.1 Моделиране на квантова операция

За целите на RTL архитектурата всяка квантова операция се моделира като краен набор от цифрови полета, извлечени от 32-битовата инструкция. Вътрешното представяне съответства на структурата `qc_instr_fields_t` и може да бъде записано като:

```text
op = (opcode, target_qubit, control_qubit, duration, flags)
```

където `opcode` определя типа на операцията, `target_qubit` и `control_qubit` определят участващите логически кубити, `duration` определя времевата продължителност или branch target, а `flags` съдържа управляващи битове за валидност и feedback поведение.

От гледна точка на scheduler-а основният въпрос е дали операцията използва ресурс, който вече е зает. Затова за всяка операция може да се дефинира множество от използвани кубити:

```text
R(op) = {q | операцията използва кубит q}
```

В реализирания dependency tracker това множество се извежда от opcode-а. Операциите `H`, `X`, `Z`, `MEASURE` и `RESET` използват `target_qubit`. Операцията `CNOT` използва едновременно `target_qubit` и `control_qubit`. Операциите `NOP`, `WAIT` и `BRANCH` не се третират като операции, които заемат qubit ресурс в dependency tracker-а. При `WAIT` блокирането се реализира чрез отделен wait counter в scheduler-а, а при `BRANCH` control-flow блокирането се управлява в top-level логиката.

Продължителността на операцията се използва за задаване на busy counter стойност. Ако полето `duration` е нула, RTL реализацията използва минимална продължителност от един такт. Това предотвратява нулево-времеви операции в busy-counter модела и осигурява предвидимо поведение в симулация.

---

## 2.4.2 Представяне чрез dependency graph / DAG

На теоретично ниво квантовата програма може да бъде представена чрез dependency graph или DAG, в който възлите са операции, а ребрата описват зависимости между операции. Ако две операции използват един и същ кубит, между тях съществува ресурсна зависимост, защото те не могат да бъдат изпълнявани независимо в произволен ред без риск от нарушаване на логическата последователност на квантовата схема.

Например последователността:

```text
H q0
X q0
```

съдържа зависимост върху `q0`, защото и двете операции използват един и същ target qubit. Обратно, последователността:

```text
H q0
X q1
```

няма такава директна qubit ресурсна зависимост между двете операции, защото те работят върху различни кубити.

В настоящата RTL реализация този графов модел се използва като архитектурна мотивация, но не се реализира пълен out-of-order DAG scheduler. Реализираният scheduler е in-order dependency-aware. Той разглежда операцията в началото на operation queue и проверява дали тя може да бъде издадена спрямо текущия busy state на кубитите. Ако операцията не може да бъде издадена, тя блокира queue-а до отпадане на зависимостта или на другото stall условие.

Това решение е по-просто от пълен DAG traversal, но е подходящо за първоначален RTL контролер, защото запазва реда на инструкциите, позволява ясно моделиране на qubit hazards и е лесно проверимо чрез directed testbench-и.

---

## 2.4.3 Ресурсни ограничения и qubit busy модел

Всеки логически кубит се разглежда като ресурс с времево състояние. Ако върху даден кубит вече се изпълнява операция, следваща операция върху същия кубит трябва да изчака до освобождаване на ресурса. Това поведение се реализира чрез масива `busy_cnt_q` в `rtl/scheduler.sv`.

Scheduler-ът използва busy counter модел:

```text
busy_cnt_q[qubit] > 0 → qubit is busy
busy_cnt_q[qubit] = 0 → qubit is free
```

Във всеки тактов цикъл всички ненулеви busy counters се намаляват с единица. Когато scheduler-ът издаде операция, която използва target и/или control qubit, съответните counters се зареждат с ефективната продължителност на операцията. Така времевият модел се свежда до дискретно отброяване на заетостта на всеки кубит.

Dependency tracker-ът получава текущия `qubit_busy` вектор и генерира `target_busy_o`, `control_busy_o`, `dependency_hazard_o` и `independent_o`. Ако поне един използван от операцията кубит е busy, `dependency_hazard_o` се активира. Ако операцията е валидна и няма hazard, тя се счита за независима спрямо текущия busy state.

Този модел не представя всички възможни физически ограничения на реална квантова система. Той не включва cross-talk constraints, topology constraints, calibration windows или pulse-level ограничения. За целите на настоящата RTL архитектура обаче busy-counter моделът е достатъчен за демонстрация на dependency-aware scheduling и stall поведение.

---

## 2.4.4 Критерий за latency и stall cycles

Latency на инструкцията може да се разглежда като броя тактови цикли от приемането ѝ във входния интерфейс до генерирането на съответния command или feedback резултат. В реализирания pipeline тази латентност зависи от състоянието на operation queue, наличието на dependency hazards, активен WAIT hold, measurement pending състояние и branch in-flight състояние.

Stall cycle възниква, когато в operation queue има валидна операция, но scheduler-ът не може да я издаде. В RTL реализацията `stall_o` в scheduler-а се активира при едно от следните условия:

```text
wait_cnt_q != 0
dependency_hazard_o == 1
tracker_independent == 1 и issue_ready_i == 0
```

Така stall-ът не се ограничава само до qubit dependency hazards. Той включва и времево задържане от `OP_WAIT`, както и downstream backpressure от top-level логиката. Това е важно, защото measurement и branch операциите могат да изискват контролерът временно да не издава нови операции от същия тип.

Основните метрики, които могат да бъдат извлечени от този модел и използвани в по-късен експериментален анализ, са:

- latency;
- stall cycles;
- issued operations per cycle;
- queue occupancy;
- measurement latency;
- feedback latency.

В Глава 2 тези метрики се използват основно за формално описание на архитектурата. Количественото им измерване чрез по-широк набор от workloads следва да бъде разгледано в експерименталната част на дисертацията.

---

## 2.4.5 Реализиран dependency-aware scheduling алгоритъм

Реализираният scheduler работи синхронно и издава най-много една операция на тактов цикъл. Той получава операцията от началото на operation queue, проверява я чрез dependency tracker и я издава само ако са изпълнени всички условия за безопасно придвижване към execution stage-а.

Условието за issue може да бъде обобщено така:

```text
can_issue = independent(op) AND issue_ready_i AND NOT wait_active
```

където `independent(op)` означава, че операцията няма dependency hazard спрямо текущите busy counters, `issue_ready_i` показва, че downstream/top-level логиката позволява издаване, а `wait_active` означава, че `wait_cnt_q` е различен от нула.

Алгоритъмът може да бъде представен със следните стъпки:

```text
1. Вземи операцията от началото на operation_queue.
2. Определи кои кубити използва операцията.
3. Провери дали target/control кубитите са busy.
4. Провери дали downstream логиката позволява issue.
5. Провери дали няма активен WAIT hold.
6. Ако всички условия са изпълнени → issue operation и pop от queue.
7. Ако има hazard, WAIT hold или backpressure → stall.
8. При issue маркирай използваните кубити като busy за duration цикли.
9. При issue на OP_WAIT зареди wait counter-а с duration.
```

Свързани файлове:

```text
rtl/dependency_tracker.sv
rtl/scheduler.sv
tb/tb_dependency_tracker.sv
tb/tb_scheduler.sv
```

Тестовата проверка на scheduler-а включва reset поведение, издаване на независими операции, задържане при CNOT dependency hazard, освобождаване след изтичане на busy counter, stall при downstream backpressure и WAIT hold поведение. Това покритие е важно, защото scheduler-ът е централният модул, който свързва dependency модела с реалния pipeline.

---

## 2.4.6 Анализ на сложността и ограничения на текущата реализация

Текущата scheduler реализация има ниска архитектурна сложност и е подходяща за първи RTL модел на instruction-driven квантов контролер. Dependency проверката се извършва само за операцията в началото на queue-а, а броят на поддържаните кубити е параметризиран чрез `NUM_QUBITS`. Busy-counter моделът изисква регистрово състояние за всеки кубит и проста логика за намаляване на counter-ите във всеки тактов цикъл.

Основното предимство на този подход е неговата предвидимост. Тъй като scheduler-ът е in-order, поведението му е лесно проследимо чрез waveform анализ и directed testbench-и. Това е особено важно на текущия етап от разработката, защото целта е да се установи стабилен RTL pipeline, който по-късно може да бъде използван като DUT в UVM среда.

Ограниченията на текущата реализация са следните:

- scheduler-ът издава операции in-order;
- няма reorder buffer;
- няма пълен DAG traversal;
- няма parallel multi-issue;
- dependency model-ът е базиран на target/control qubit busy state;
- не се моделират физически topology constraints;
- WAIT блокира scheduler-а чрез глобален wait counter;
- branch control-flow се управлява на top-level ниво, а не чрез отделен branch prediction или program counter механизъм.

Тези ограничения не обезсилват текущата архитектура, но трябва да бъдат ясно разграничени от бъдещи разширения. Възможно следващо развитие е добавяне на по-сложен scheduler, който анализира повече от една операция в queue-а, използва dependency graph представяне и позволява out-of-order или multi-issue изпълнение при независими операции.

### Проследимост на раздели 2.1–2.4 към реалния RTL код

Разделите `2.1`–`2.4` имат предимно архитектурна и формална роля. Поради това в тях не се дублират всички SystemVerilog откъси, но всяко съществено твърдение трябва да бъде проследимо към реален RTL фрагмент. Конкретните кодови откъси са събрани в `2.5`, където се описва имплементацията на модулите. Следната таблица показва къде концептуалните твърдения от началните раздели се свързват с реалния код.

| Раздел | Основно твърдение | Реален RTL артефакт | Кодов фрагмент в 2.5 |
|---|---|---|---|
| `2.1` | Контролерът е instruction-driven pipeline | `rtl/quantum_controller_top.sv` | Фрагменти 2.8 и 2.9 |
| `2.1.2` | Използва се фиксиран 32-битов instruction format | `rtl/qc_pkg.sv` | Фрагмент 2.1 |
| `2.1.2` | Valid/conditional/feedback/expected flags имат фиксирани битови позиции | `rtl/qc_pkg.sv`, `rtl/instruction_decoder.sv`, `rtl/feedback_unit.sv` | Фрагменти 2.1, 2.2 и 2.7 |
| `2.1.3` | RTL моделът не реализира физически backend, а цифров command/control слой | `rtl/execution_controller.sv`, `rtl/quantum_controller_top.sv` | Описано в 2.5.6 и фрагмент 2.8 |
| `2.1.3` | Measurement и branch имат top-level control-flow защита | `rtl/measurement_controller.sv`, `rtl/feedback_unit.sv`, `rtl/quantum_controller_top.sv` | Фрагменти 2.6, 2.7, 2.8 и 2.9 |
| `2.2` | Проектът е организиран около реални RTL, testbench, log и synthesis артефакти | `rtl/`, `tb/`, `results/`, `rtl_synth/` | Няма отделен кодов откъс; използват се препратки към файлове и артефакти |
| `2.3` | Top-level модулът свързва decoder, queue, scheduler, execution, measurement и feedback блокове | `rtl/quantum_controller_top.sv` | Фрагменти 2.8 и 2.9 |
| `2.3` | Queue flush при taken branch премахва по-младите инструкции | `rtl/operation_queue.sv`, `rtl/quantum_controller_top.sv` | Фрагменти 2.3 и 2.8 |
| `2.4` | Scheduler-ът е in-order dependency-aware и използва busy-counter модел | `rtl/dependency_tracker.sv`, `rtl/scheduler.sv` | Фрагменти 2.4 и 2.5 |
| `2.4` | `OP_WAIT` блокира scheduler-а чрез отделен wait counter | `rtl/scheduler.sv` | Фрагмент 2.5 |

Така началните раздели остават четими като архитектурно описание, а реалните SystemVerilog доказателства са концентрирани в раздел `2.5`. При финалното прехвърляне към `.docx` тази таблица може да се запази като traceability таблица или да се използва като редакторска карта за поставяне на кодовите откъси.

---

# 2.5 RTL имплементация на основните модули

## 2.5.1 Instruction package и instruction format (`qc_pkg.sv`)

Файлът `rtl/qc_pkg.sv` дефинира общата архитектурна основа на контролера. Той съдържа параметрите за ширината на инструкцията, opcode полето, qubit identifier полетата, duration полето, flags полето и reserved полето. По този начин всички останали RTL модули използват единна дефиниция на instruction format-а и не дублират локални константи.

В package файла са дефинирани следните основни параметри:

| Параметър | Стойност | Значение |
|---|---:|---|
| `INSTR_W` | 32 | Обща ширина на входната инструкция |
| `OPCODE_W` | 4 | Ширина на opcode полето |
| `QUBIT_ID_W` | 4 | Ширина на target/control qubit полетата |
| `DURATION_W` | 12 | Ширина на duration или branch target полето |
| `FLAGS_W` | 4 | Ширина на управляващите флагове |
| `RESERVED_W` | 4 | Ширина на резервираното поле |
| `MAX_QUBITS` | 16 | Максимален брой адресируеми логически кубити |

Opcode стойностите са представени чрез enum типа `qc_opcode_e`. Поддържаните операции са `OP_NOP`, `OP_H`, `OP_X`, `OP_Z`, `OP_CNOT`, `OP_MEASURE`, `OP_WAIT`, `OP_RESET` и `OP_BRANCH`. Допълнително е дефинирана стойността `OP_INVALID`, която служи като представяне на невалидна операция, но decoder модулът маркира непознатите opcode стойности чрез отделния сигнал `illegal_o`.

Управляващите флагове са дефинирани чрез локални константи за битовите позиции. `FLAG_VALID_BIT` указва дали инструкцията е валидна за приемане, `FLAG_CONDITIONAL_BIT` и `FLAG_FEEDBACK_BIT` участват в условната branch логика, а `FLAG_EXPECTED_BIT` задава очакваната measurement стойност при feedback проверка. Тези дефиниции са особено важни, защото едни и същи flag битове се използват от instruction decoder-а, feedback unit-а и top-level control-flow логиката.

За структурирано представяне на инструкцията се използва `qc_instr_fields_t`. Тази packed структура съдържа полетата `opcode`, `target_qubit`, `control_qubit`, `duration`, `flags` и `reserved`. Допълнително `qc_instr_t` е дефиниран като packed union между raw 32-битова стойност и structured fields представяне. Така decoder-ът може да приема инструкцията като 32-битова дума, но да извежда отделните полета чрез типизиран достъп.

Кодов фрагмент 2.1 показва реалните flag позиции и структурираното представяне на инструкцията в `rtl/qc_pkg.sv`.

```systemverilog
localparam int FLAG_VALID_BIT       = 3;
localparam int FLAG_CONDITIONAL_BIT = 2;
localparam int FLAG_FEEDBACK_BIT    = 1;
localparam int FLAG_EXPECTED_BIT    = 0;

typedef struct packed {
    qc_opcode_e             opcode;
    logic [QUBIT_ID_W-1:0]  target_qubit;
    logic [QUBIT_ID_W-1:0]  control_qubit;
    logic [DURATION_W-1:0]  duration;
    logic [FLAGS_W-1:0]     flags;
    logic [RESERVED_W-1:0]  reserved;
} qc_instr_fields_t;
```

## 2.5.2 Instruction Decoder (`instruction_decoder.sv`)

Модулът `rtl/instruction_decoder.sv` реализира първия етап от pipeline-а. Неговата задача е да приеме входната 32-битова инструкция `instr_i` и да извлече основните архитектурни полета. Това се извършва чрез union представянето `qc_instr_t`, дефинирано в package файла. Raw входната стойност се записва в `instr_decoded.raw`, а отделните полета се достъпват чрез `instr_decoded.fields`.

Decoder-ът генерира следните изходи:

| Изход | Роля |
|---|---|
| `opcode_o` | Код на операцията |
| `target_qubit_o` | Целеви кубит |
| `control_qubit_o` | Контролен кубит при двукубитни операции |
| `duration_o` | Продължителност или branch target |
| `flags_o` | Управляващи флагове |
| `valid_o` | Валидност според `FLAG_VALID_BIT` |
| `illegal_o` | Индикация за неподдържан opcode |

Сигналът `valid_o` не се извежда от opcode-а, а от `flags[FLAG_VALID_BIT]`. Това позволява инструкцията да носи отделна информация за валидност, независимо от конкретния тип операция. Top-level модулът използва този сигнал заедно с `instr_valid_i`, `instr_ready_o` и `illegal_o`, за да реши дали инструкцията да бъде записана в operation queue.

Illegal opcode логиката се реализира чрез `unique case` върху декодирания opcode. Поддържаните операции се маркират като легални, а всички останали стойности активират `illegal_o`. В top-level интеграцията нелегалната инструкция не се записва в queue-а, а се отразява чрез диагностичния сигнал `illegal_instr_o`. Това поведение е проверено чрез `tb/tb_instruction_decoder.sv` и чрез top-level invalid opcode сценарий в `tb/tb_quantum_controller_top.sv`.

Кодов фрагмент 2.2 показва как `instruction_decoder.sv` извлича valid bit-а от flags полето и маркира неподдържаните opcode стойности.

```systemverilog
assign valid_o = instr_decoded.fields.flags[FLAG_VALID_BIT];

always_comb begin
    illegal_o = 1'b0;

    unique case (instr_decoded.fields.opcode)
        OP_NOP, OP_H, OP_X, OP_Z, OP_CNOT,
        OP_MEASURE, OP_WAIT, OP_RESET, OP_BRANCH: begin
            illegal_o = 1'b0;
        end

        default: begin
            illegal_o = 1'b1;
        end
    endcase
end
```

## 2.5.3 Operation Queue (`operation_queue.sv`)

Модулът `rtl/operation_queue.sv` реализира FIFO буфер за декодирани инструкции. Той приема вече структурирана инструкция от тип `qc_instr_fields_t` и я съхранява до момента, в който scheduler-ът може да я разгледа за издаване. Queue-ът е параметризиран чрез `DEPTH`, което позволява промяна на броя буферирани операции без промяна в останалата логика.

Вътрешната реализация използва масив `mem_q`, write pointer `wr_ptr_q`, read pointer `rd_ptr_q` и counter `count_q`. Сигналите `full_o` и `empty_o` се извеждат директно от стойността на counter-а. `count_o` предоставя наблюдаемост върху броя инструкции в queue-а и се използва като debug/status изход на top-level модула.

Push операция се изпълнява, когато `push_i` е активен и queue-ът не е пълен. Pop операция се изпълнява, когато `pop_i` е активен и queue-ът не е празен. При едновременно push и pop counter-ът запазва стойността си, защото една операция се добавя и една се премахва в същия тактов цикъл. Pointer-ите се обновяват чрез помощна функция за wrap-around, така че структурата да работи като кръгов буфер.

Съществена част от текущата RTL реализация е `flush_i` входът. При активиране на `flush_i` queue-ът изчиства pointer-ите, counter-а и вътрешната памет. Това поведение се използва от top-level модула при taken branch. Когато `feedback_valid_o` и `branch_taken_o` са активни едновременно, top-level логиката активира queue flush, за да премахне по-младите инструкции, които вече са били приети след branch операцията.

Operation queue поведението е проверено чрез `tb/tb_operation_queue.sv`. Testbench-ът покрива reset, push, pop, full queue сценарий и flush queue сценарий. Това покритие е важно, защото queue-ът е границата между входния instruction поток и scheduler-а.

Кодов фрагмент 2.3 показва реалната flush логика в `rtl/operation_queue.sv`.

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
        wr_ptr_q <= '0;
        rd_ptr_q <= '0;
        count_q  <= '0;
    end else if (flush_i) begin
        wr_ptr_q <= '0;
        rd_ptr_q <= '0;
        count_q  <= '0;

        for (int i = 0; i < DEPTH; i++) begin
            mem_q[i] <= '0;
        end
    end else begin
        if (push_en) begin
            mem_q[wr_ptr_q] <= instr_i;
            wr_ptr_q        <= ptr_next(wr_ptr_q);
        end

        if (pop_en) begin
            rd_ptr_q <= ptr_next(rd_ptr_q);
        end

        unique case ({push_en, pop_en})
            2'b10: count_q <= count_q + CNT_W'(1);
            2'b01: count_q <= count_q - CNT_W'(1);
            default: count_q <= count_q;
        endcase
    end
end
```

## 2.5.4 Dependency Tracker (`dependency_tracker.sv`)

Модулът `rtl/dependency_tracker.sv` определя кои кубити се използват от дадена операция и дали съществува dependency hazard спрямо текущия busy state. Той не пази вътрешно състояние, а работи като combinational блок. Входовете му са валидността на инструкцията, самата декодирана инструкция и векторът `qubit_busy_i`, който се подава от scheduler-а.

Първата задача на dependency tracker-а е да определи дали операцията използва target qubit и/или control qubit. Еднокубитните операции `OP_H`, `OP_X`, `OP_Z`, `OP_MEASURE` и `OP_RESET` използват само `target_qubit`. Операцията `OP_CNOT` използва както `target_qubit`, така и `control_qubit`. Операциите `OP_NOP`, `OP_WAIT` и `OP_BRANCH` не заемат qubit ресурс в dependency tracker модела.

След определяне на използваните ресурси модулът генерира `qubit_mask_o`, `target_busy_o` и `control_busy_o`. Ако операцията е валидна и някой от използваните кубити е маркиран като busy, се активира `dependency_hazard_o`. Ако операцията е валидна и няма hazard, се активира `independent_o`.

Този модул отделя dependency анализа от scheduler state логиката. Така scheduler-ът не трябва сам да съдържа opcode-specific resource detection логика, а може да използва готовите сигнали от tracker-а. Модулът е проверен чрез `tb/tb_dependency_tracker.sv`, който покрива свободен target qubit, busy target hazard, busy control hazard при `CNOT`, независими операции върху различни кубити и `NOP` сценарий.

Кодов фрагмент 2.4 показва реалното определяне на използваните qubit ресурси и dependency hazard в `rtl/dependency_tracker.sv`.

```systemverilog
unique case (instr_i.opcode)
    OP_H, OP_X, OP_Z, OP_MEASURE, OP_RESET: begin
        uses_target_o  = 1'b1;
        uses_control_o = 1'b0;
    end

    OP_CNOT: begin
        uses_target_o  = 1'b1;
        uses_control_o = 1'b1;
    end

    default: begin
        uses_target_o  = 1'b0;
        uses_control_o = 1'b0;
    end
endcase

assign dependency_hazard_o = instr_valid_i &&
                             ((uses_target_o  && target_busy_o) ||
                              (uses_control_o && control_busy_o));

assign independent_o = instr_valid_i && !dependency_hazard_o;
```

## 2.5.5 Scheduler (`scheduler.sv`)

Модулът `rtl/scheduler.sv` реализира in-order dependency-aware scheduling. Той получава операцията от началото на operation queue и решава дали тя може да бъде издадена към execution controller-а. Scheduler-ът е параметризиран чрез `NUM_QUBITS`, което определя броя busy counters и ширината на `qubit_busy_o` статуса.

Основното вътрешно състояние на scheduler-а е масивът `busy_cnt_q`. Всеки елемент от този масив съответства на един логически кубит. Ако counter-ът за даден кубит е различен от нула, кубитът се счита за зает. Във всеки тактов цикъл ненулевите counters се намаляват с единица. При издаване на операция, която използва target и/или control qubit, съответните counters се зареждат с ефективната продължителност на операцията.

Scheduler-ът инстанцира `dependency_tracker`, който определя дали текущата операция е независима спрямо busy state-а. Освен dependency резултата scheduler-ът използва и входа `issue_ready_i`. Този вход позволява top-level логиката да наложи downstream backpressure, например когато има pending measurement или branch операция. По този начин scheduler-ът не работи изолирано, а се съобразява с control-flow състоянието на целия контролер.

Условието за издаване е:

```text
can_issue = tracker_independent && issue_ready_i && !wait_active
```

Ако това условие е изпълнено, scheduler-ът активира `issue_valid_o`, подава инструкцията чрез `issue_instr_o` и активира `queue_pop_o`. Ако условието не е изпълнено, но има валидна инструкция, се активира `stall_o`. Stall може да възникне поради dependency hazard, downstream backpressure или активен WAIT hold.

Операцията `OP_WAIT` се обработва чрез отделен `wait_cnt_q`. При issue на `OP_WAIT` counter-ът се зарежда с ефективната продължителност на операцията. Докато `wait_cnt_q` е различен от нула, `wait_active` блокира издаването на следващи операции. Така WAIT се реализира като глобално времево задържане на scheduler-а, а не като qubit-specific dependency.

Scheduler поведението е проверено чрез `tb/tb_scheduler.sv`. Тестовете покриват издаване на независими операции, dependency hazard при `CNOT`, освобождаване след изтичане на busy counter, backpressure stall и WAIT scheduler hold. Тази проверка е ключова, защото scheduler-ът е централният модул, който определя кога instruction pipeline-ът напредва и кога се задържа.

Кодов фрагмент 2.5 показва реалните `can_issue`, `stall_o` и `OP_WAIT` части от `rtl/scheduler.sv`.

```systemverilog
assign operation_duration = (instr_i.duration == '0) ? ONE_CYCLE : instr_i.duration;
assign wait_active        = (wait_cnt_q != '0);

assign can_issue   = tracker_independent && issue_ready_i && !wait_active;
assign queue_pop_o = can_issue;
assign stall_o     = instr_valid_i &&
                      (wait_active ||
                       tracker_dependency_hazard ||
                       (tracker_independent && !issue_ready_i));

if (can_issue) begin
    issue_valid_o <= 1'b1;
    issue_instr_o <= instr_i;

    if (instr_i.opcode == OP_WAIT) begin
        wait_cnt_q <= operation_duration;
    end
end
```

## 2.5.6 Execution Controller и цифров command интерфейс (`execution_controller.sv`)

Модулът `rtl/execution_controller.sv` преобразува издадената от scheduler-а операция в цифров command интерфейс. Той не реализира аналогов pulse generator и не генерира физически управляващи импулси. Неговата роля е да класифицира операцията и да изведе цифрови сигнали, които описват какъв тип команда трябва да бъде изпълнена от абстрактния execution layer.

Execution controller-ът приема `issue_valid_i` и `issue_instr_i`. В текущата реализация `issue_ready_o` е постоянно активен, което означава, че самият execution controller не въвежда допълнителен локален backpressure. Backpressure към scheduler-а се управлява на top-level ниво чрез `issue_ready_i` входа на scheduler-а.

Когато има валидна issued операция, модулът генерира `command_valid_o` и копира инструкцията към `command_instr_o` за всички реални команди, които трябва да продължат към следващите блокове. Еднокубитните и двукубитните gate операции активират `gate_cmd_o`. `OP_MEASURE` активира `measure_cmd_o`, `OP_WAIT` активира `wait_cmd_o`, `OP_RESET` активира `reset_cmd_o`, а `OP_BRANCH` активира `branch_cmd_o`. `OP_NOP` активира `nop_cmd_o`, но не генерира валиден command payload чрез `command_valid_o`.

Ако execution controller-ът получи неподдържан opcode, той активира `illegal_issue_o`. Това е защитен механизъм за случаи, при които невалидна операция би достигнала execution stage-а. При нормална top-level работа illegal instructions се спират още преди queue-а, но `illegal_issue_o` остава полезен диагностичен сигнал и е покрит от `tb/tb_execution_controller.sv`.

Цифровият command интерфейс е важна граница в архитектурата. От едната страна стои instruction pipeline-ът, който обработва и планира операции. От другата страна са measurement и feedback блоковете, които реагират на конкретни command типове. Това разделение позволява в бъдеще към същия command интерфейс да бъде добавен по-нисък слой за pulse-level управление, без настоящата работа да твърди, че такъв слой вече е реализиран.

## 2.5.7 Measurement Controller (`measurement_controller.sv`)

Модулът `rtl/measurement_controller.sv` обработва `OP_MEASURE` командите и съхранява получените measurement резултати. Той приема command интерфейса от execution controller-а и реагира само когато `command_valid_i` е активен и opcode-ът на командата е `OP_MEASURE`.

При валидна measurement команда модулът записва target qubit-а като pending qubit, активира `pending_q` и генерира еднотактов measurement request чрез `measure_request_valid_o`. Кубитът, който трябва да бъде измерен, се извежда чрез `measure_qubit_o`. Докато `pending_q` е активен, `measurement_busy_o` показва, че измерването все още очаква резултат.

Measurement резултатите се подават абстрактно чрез `measurement_result_valid_i` и `measurement_result_i`. Когато пристигне резултат и има pending measurement, модулът изчиства pending състоянието, активира `result_valid_o`, извежда измерения кубит чрез `result_qubit_o` и стойността чрез `result_value_o`. Допълнително резултатът се записва в два вектора: `measurement_valid_o` показва за кои кубити има наличен резултат, а `measurement_results_o` съдържа съответните стойности.

Ако `measurement_result_valid_i` се активира без да има pending measurement, модулът активира `unexpected_result_o`. Това поведение е важно за диагностика, защото отделя нормалното връщане на резултат от некоректен външен stimulus или protocol violation.

Top-level модулът използва `measurement_busy_o`, за да блокира издаването на нова `MEASURE` операция, докато предходната measurement операция не получи резултат. Така measurement controller-ът и top-level backpressure логиката заедно осигуряват едновременно само една pending measurement операция в текущата архитектура.

Поведенческата проверка се извършва чрез `tb/tb_measurement_controller.sv`, който покрива measurement request, съхранение на резултат, втори measurement резултат, игнориране на non-measure command и unexpected result сценарий.

Кодов фрагмент 2.6 показва pending measurement логиката и записването на резултата в `rtl/measurement_controller.sv`.

```systemverilog
assign command_ready_o    = !pending_q;
assign measurement_busy_o = pending_q;

if (command_valid_i && command_ready_o) begin
    if (command_instr_i.opcode == OP_MEASURE) begin
        pending_q               <= 1'b1;
        pending_qubit_q         <= command_instr_i.target_qubit;
        measure_request_valid_o <= 1'b1;
        measure_qubit_o         <= command_instr_i.target_qubit;
    end
end

if (measurement_result_valid_i) begin
    if (pending_q) begin
        pending_q <= 1'b0;
        measurement_valid_o[pending_qubit_q]   <= 1'b1;
        measurement_results_o[pending_qubit_q] <= measurement_result_i;
    end else begin
        unexpected_result_o <= 1'b1;
    end
end
```

## 2.5.8 Feedback Unit (`feedback_unit.sv`)

Модулът `rtl/feedback_unit.sv` реализира базовата feedback/branch логика на контролера. Той приема command интерфейса, branch command индикацията и текущите measurement result регистри. Feedback unit-ът се активира само при валидна `OP_BRANCH` команда, активен `branch_cmd_i` и валиден instruction flag.

Branch операцията използва `target_qubit` като кубит, чийто measurement резултат трябва да бъде проверен. Наличността на резултат се определя чрез `measurement_valid_i[selected_qubit]`, а самата стойност се чете от `measurement_results_i[selected_qubit]`. Branch target-ът се извежда чрез `branch_target_o` и в текущия instruction format се взема от полето `duration`.

Conditional branch поведение се определя чрез `FLAG_CONDITIONAL_BIT` и `FLAG_FEEDBACK_BIT`. Ако поне един от тези флагове е активен, branch операцията се третира като условна. Очакваната стойност се взема от `FLAG_EXPECTED_BIT`. Ако measurement резултатът за избрания кубит е наличен, feedback unit-ът активира `condition_checked_o`, извежда измерената стойност чрез `feedback_value_o` и задава `branch_taken_o` според сравнението между измерената и очакваната стойност.

Ако branch операцията е условна, но няма наличен measurement резултат за избрания кубит, се активира `missing_measurement_o`, а branch не се взема. Това поведение предотвратява вземането на control-flow решение върху несъществуващ measurement state.

Ако branch операцията не е conditional или feedback-related, модулът я третира като unconditional branch. В този случай `branch_taken_o` се активира без проверка на measurement резултат. И при conditional, и при unconditional branch `feedback_valid_o` показва, че feedback unit-ът е обработил branch командата и branch decision-ът е валиден за текущия цикъл.

Feedback unit поведението е проверено чрез `tb/tb_feedback_unit.sv`. Testbench-ът покрива conditional branch taken, conditional branch not taken, missing measurement, unconditional branch и invalid command_valid сценарий.

Кодов фрагмент 2.7 показва реалната conditional/unconditional branch логика в `rtl/feedback_unit.sv`.

```systemverilog
assign conditional_branch = command_instr_i.flags[FLAG_CONDITIONAL_BIT] |
                            command_instr_i.flags[FLAG_FEEDBACK_BIT];
assign expected_value     = command_instr_i.flags[FLAG_EXPECTED_BIT];

if (command_valid_i && branch_cmd_i &&
    command_instr_i.opcode == OP_BRANCH &&
    command_instr_i.flags[FLAG_VALID_BIT]) begin

    feedback_valid_o <= 1'b1;
    branch_target_o  <= command_instr_i.duration;

    if (conditional_branch) begin
        if (selected_valid) begin
            condition_checked_o <= 1'b1;
            feedback_value_o    <= selected_result;
            branch_taken_o      <= (selected_result == expected_value);
        end else begin
            missing_measurement_o <= 1'b1;
            branch_taken_o        <= 1'b0;
        end
    end else begin
        branch_taken_o <= 1'b1;
    end
end
```

## 2.5.9 Top-level интеграция (`quantum_controller_top.sv`)

Модулът `rtl/quantum_controller_top.sv` интегрира всички основни RTL блокове в единен instruction pipeline. Той приема raw инструкцията, декодира я, записва я в operation queue, подава операцията към scheduler-а, генерира command интерфейса, обработва measurement резултати и извежда feedback/branch решения.

Входната ready/valid логика се управлява чрез `instr_ready_o`. Контролерът приема нова инструкция само ако operation queue не е full и ако не се извършва queue flush. Валидна и легална инструкция се записва в queue-а чрез `queue_push`. Нелегален opcode активира `illegal_instr_o` и не се допуска във вътрешния pipeline.

Top-level модулът добавя control-flow backpressure върху scheduler-а чрез `scheduler_issue_ready`. Този сигнал отчита три основни условия: липса на queue flush, липса на branch issue blocking и липса на measurement issue blocking за текущата операция. Measurement issue blocking се активира, когато measurement controller-ът е busy или когато в pipeline-а вече има `OP_MEASURE` операция. Branch issue blocking се активира, когато има in-flight branch или когато в pipeline-а вече има `OP_BRANCH` операция.

Branch in-flight състоянието се пази чрез `branch_inflight_q`. То се задава при issue на `OP_BRANCH` и се изчиства при `feedback_valid_o`. Това предотвратява издаването на нов branch преди предходният branch decision да бъде обработен. Ако feedback unit-ът активира едновременно `feedback_valid_o` и `branch_taken_o`, top-level модулът активира `queue_flush`, който изчиства operation queue. Тази логика предотвратява изпълнението на по-млади инструкции, които са били буферирани след branch-а.

Measurement backpressure логиката използва `measurement_busy_o` и текущите pipeline състояния, за да предотврати второ pending измерване. Това е важно, защото `measurement_controller.sv` в текущата архитектура пази едно pending measurement състояние. Top-level защитата гарантира, че този модел не се нарушава от последователни `MEASURE` инструкции.

Top-level модулът изнася както основните функционални изходи, така и debug/status сигнали. Изходите `issue_*` позволяват наблюдение на scheduler stage-а, `command_*` описват execution command stage-а, measurement изходите описват заявките и резултатите от измерванията, а feedback изходите описват branch решенията. Допълнително `queue_count_o`, `qubit_busy_o`, `scheduler_stall_o`, `illegal_instr_o` и `illegal_issue_o` дават видимост върху вътрешното състояние на контролера.

Интеграционното поведение е проверено чрез `tb/tb_quantum_controller_top.sv`. Тестът покрива reset, нормални gate команди, measurement request и result, conditional feedback branch, measurement backpressure, taken branch flush и invalid opcode поведение. Този testbench е основното доказателство, че отделните RTL модули работят съгласувано като единен контролер.

Кодов фрагмент 2.8 показва top-level control-flow логиката в `rtl/quantum_controller_top.sv`, която свързва branch decision-а, queue flush-а и scheduler backpressure-а.

```systemverilog
assign queue_flush = feedback_valid_o && branch_taken_o;
assign instr_ready_o = !queue_full && !queue_flush;

assign measurement_issue_blocked =
    measurement_busy_o ||
    (sched_issue_valid && (sched_issue_instr.opcode == OP_MEASURE)) ||
    (command_valid_o && (command_instr.opcode == OP_MEASURE));

assign branch_issue_blocked =
    branch_inflight_q ||
    (sched_issue_valid && (sched_issue_instr.opcode == OP_BRANCH)) ||
    (command_valid_o && (command_instr.opcode == OP_BRANCH));

assign scheduler_issue_ready =
    !queue_flush &&
    !branch_issue_blocked &&
    !(measurement_issue_blocked &&
      !queue_empty &&
      (queue_instr.opcode == OP_MEASURE));
```

Кодов фрагмент 2.9 показва регистровото branch in-flight състояние в същия top-level модул.

```systemverilog
if (feedback_valid_o) begin
    branch_inflight_q <= 1'b0;
end

if (sched_issue_valid && (sched_issue_instr.opcode == OP_BRANCH)) begin
    branch_inflight_q <= 1'b1;
end
```

---

# 2.6 FSM и вътрешни контролни състояния

## 2.6.1 Queue и scheduler поведение

В текущата RTL архитектура няма един централен монолитен FSM, който управлява целия контролер. Вместо това управлението е разпределено между няколко локални регистрови състояния и handshake сигнали. Този подход е подходящ за модулна RTL архитектура, защото всеки блок пази само състоянието, което е необходимо за неговата функция, а top-level модулът координира взаимодействието между блоковете.

Operation queue състоянието се определя от `wr_ptr_q`, `rd_ptr_q` и `count_q`. Когато `count_q` е нула, `empty_o` е активен и scheduler-ът няма валидна операция за разглеждане. Когато `count_q` достигне параметъра `DEPTH`, `full_o` е активен и top-level модулът деактивира `instr_ready_o`, за да спре приемането на нови инструкции.

Scheduler-ът получава `instr_valid_i`, който в top-level интеграцията се свързва с `!queue_empty`. Ако queue-ът не е празен, scheduler-ът проверява операцията на изхода на queue-а. При успешно issue се активира `queue_pop_o`, което премества read pointer-а на queue-а към следващата операция. Ако scheduler-ът не може да издаде операцията, queue-ът запазва текущия read pointer и същата операция остава на изхода до отпадане на stall условието.

Така queue и scheduler заедно реализират in-order поведение. Операцията в началото на queue-а е единствената операция, която може да бъде издадена. Следващите операции не се разглеждат, докато текущата операция не бъде pop-ната. Това е важна архитектурна характеристика, защото опростява dependency логиката, но ограничава възможността за заобикаляне на блокираща операция чрез по-късна независима операция.

При taken branch top-level модулът активира `flush_i` на operation queue. Flush състоянието има приоритет над обичайните push/pop операции и връща queue-а в празно състояние. По този начин control-flow промяната прекъсва нормалното FIFO движение и премахва инструкциите, които вече не са валидни спрямо взетия branch.

## 2.6.2 Busy-counter модел за кубити

Busy-counter моделът е основният вътрешен state механизъм на scheduler-а. За всеки логически кубит се поддържа counter в масива `busy_cnt_q`. Ако counter-ът е различен от нула, съответният кубит се счита за зает и dependency tracker-ът може да маркира hazard при следваща операция върху същия кубит.

Във всеки тактов цикъл scheduler-ът обхожда всички counters и намалява ненулевите стойности с единица. Това реализира дискретен времеви модел, при който продължителността на операцията се измерва в clock cycles. При issue на операция, която използва target qubit, counter-ът за този target се зарежда с `operation_duration`. При `CNOT` се зареждат counters както за target, така и за control qubit.

Ефективната продължителност се определя чрез:

```text
operation_duration = (duration == 0) ? 1 : duration
```

Така дори инструкция с нулево duration поле заема ресурса поне за един такт. Това поведение избягва неясни нулево-времеви операции и прави busy state-а наблюдаем в simulation waveform.

Операциите `WAIT` и `BRANCH` не заемат конкретен qubit resource чрез dependency tracker-а. `WAIT` използва отделен глобален wait counter, а branch контролът се управлява чрез top-level branch in-flight логика. Това разделение позволява qubit busy моделът да остане фокусиран върху ресурсните зависимости между операции, които реално използват target/control кубити.

Кодов фрагмент 2.12 показва регистровата логика, чрез която scheduler-ът намалява busy counters във всеки тактов цикъл и ги зарежда при успешно issue на операция. Този фрагмент допълва описанието на busy-counter модела, защото показва, че заетостта на кубитите не е абстрактна променлива, а реално синхронно RTL състояние в `rtl/scheduler.sv`.

**Кодов фрагмент 2.12. Обновяване на busy-counter състоянието в scheduler.sv**  
Източник: `rtl/scheduler.sv`

```systemverilog
for (int i = 0; i < NUM_QUBITS; i++) begin
    if (busy_cnt_q[i] != '0) begin
        busy_cnt_q[i] <= busy_cnt_q[i] - ONE_CYCLE;
    end
end

if (wait_cnt_q != '0) begin
    wait_cnt_q <= wait_cnt_q - ONE_CYCLE;
end

if (can_issue) begin
    issue_valid_o <= 1'b1;
    issue_instr_o <= instr_i;

    if (instr_i.opcode == OP_WAIT) begin
        wait_cnt_q <= operation_duration;
    end

    if (tracker_uses_target) begin
        busy_cnt_q[instr_i.target_qubit] <= operation_duration;
    end

    if (tracker_uses_control) begin
        busy_cnt_q[instr_i.control_qubit] <= operation_duration;
    end
end
```


## 2.6.3 Measurement pending logic

Measurement controller-ът използва локално pending състояние, реализирано чрез `pending_q` и `pending_qubit_q`. Когато execution controller-ът генерира валидна `OP_MEASURE` команда, measurement controller-ът записва target qubit-а в `pending_qubit_q` и активира `pending_q`. В същия момент се генерира еднотактов `measure_request_valid_o` сигнал към външния measurement интерфейс.

Докато `pending_q` е активен, `measurement_busy_o` също е активен. Този сигнал се използва от top-level логиката, за да блокира издаването на нова measurement операция. Така текущата архитектура поддържа едно pending measurement състояние в даден момент. Това ограничение е съзнателно и улеснява feedback логиката, защото връщаният measurement резултат се свързва с точно един pending qubit.

Когато `measurement_result_valid_i` се активира, measurement controller-ът проверява дали има pending measurement. Ако има, резултатът се записва в `measurement_results_o[pending_qubit_q]`, а съответният valid bit в `measurement_valid_o[pending_qubit_q]` се активира. Едновременно с това се генерира `result_valid_o`, който изнася измерения кубит и стойността на резултата.

Ако резултат пристигне без pending measurement, модулът активира `unexpected_result_o`. Това поведение е важно за верификацията, защото позволява testbench или бъдещ scoreboard да открие несъответствие между заявките за измерване и пристигащите резултати.

## 2.6.4 Feedback/branch decision logic

Feedback/branch decision логиката е разпределена между `feedback_unit.sv` и top-level модула. Feedback unit-ът взема самото branch решение, а top-level модулът управлява branch in-flight състоянието и queue flush поведението.

При `OP_BRANCH` команда feedback unit-ът първо проверява дали инструкцията е валидна чрез `FLAG_VALID_BIT`. След това определя дали branch-ът е условен чрез `FLAG_CONDITIONAL_BIT` и `FLAG_FEEDBACK_BIT`. Ако branch-ът е условен, модулът използва `target_qubit` като индекс към measurement result state-а. Ако за този кубит има наличен резултат, стойността се сравнява с `FLAG_EXPECTED_BIT`. При съвпадение `branch_taken_o` се активира.

Ако условният branch няма наличен measurement резултат, feedback unit-ът активира `missing_measurement_o` и не взема branch-а. Това предотвратява неопределено control-flow поведение. Ако branch-ът е безусловен, `branch_taken_o` се активира без measurement проверка.

Top-level модулът пази `branch_inflight_q`. Това състояние се активира при issue на `OP_BRANCH` и се изчиства при `feedback_valid_o`. Докато branch е in-flight, scheduler readiness логиката блокира издаването на нов branch. Ако branch decision-ът е valid и branch е taken, top-level модулът активира `queue_flush`, което изчиства всички инструкции, които са останали в operation queue след branch-а.

Тази логика реализира базова control-flow коректност без отделен program counter или branch prediction механизъм. Branch target-ът се извежда като `branch_target_o`, но настоящият RTL модел не реализира самостоятелно fetch пренасочване към нов адрес. Това е важно ограничение и трябва да се разглежда като бъдещо разширение при свързване на контролера с instruction memory или по-пълен front-end.

---

# 2.7 Pipeline архитектура и end-to-end изпълнение

## 2.7.1 Път на инструкцията през контролера

Пътят на инструкцията през контролера започва от входа `instr_i`, където инструкцията се подава като 32-битова дума. Сигналът `instr_valid_i` указва, че входната инструкция е валидна от гледна точка на външния източник, а `instr_ready_o` показва дали контролерът може да я приеме. При едновременно активни valid и ready сигнали инструкцията се разглежда от decoder-а.

`instruction_decoder` извлича отделните полета и генерира `valid_o` и `illegal_o`. Ако инструкцията е валидна според flags полето и opcode-ът е допустим, top-level логиката я записва в operation queue. Ако opcode-ът е нелегален, инструкцията не влиза в queue-а и се активира `illegal_instr_o`.

След запис в queue-а инструкцията изчаква да достигне изхода на FIFO структурата. Scheduler-ът разглежда само операцията в началото на queue-а. Ако няма dependency hazard, няма активен WAIT hold и top-level логиката разрешава issue, scheduler-ът активира `issue_valid_o`, подава операцията към execution controller-а и pop-ва queue-а.

Execution controller-ът класифицира операцията и генерира цифров command интерфейс. За gate, measure, wait, reset и branch операции се активира `command_valid_o`, а съответният command classifier сигнал показва типа на операцията. От този момент нататък measurement controller и feedback unit реагират само на командите, които са релевантни за тях.

При gate операции основният наблюдаем резултат е активирането на `gate_cmd_o` и изходните command полета. При measurement операции се генерира measurement request. При branch операции се генерира feedback decision. Така една входна инструкция преминава през декодиране, буфериране, scheduling, command generation и евентуално measurement/feedback обработка.

## 2.7.2 Gate/measure/wait/reset/branch командни сценарии

Поддържаните opcode-и преминават през общ pipeline, но след execution controller stage-а имат различно поведение.

Gate операциите `OP_H`, `OP_X`, `OP_Z` и `OP_CNOT` се третират като операции, които генерират `gate_cmd_o`. При еднокубитните gate операции dependency tracker-ът използва target qubit-а, а при `CNOT` използва едновременно target и control qubit. След issue съответните busy counters се зареждат с продължителността на операцията.

`OP_MEASURE` се третира като операция върху target qubit и след issue генерира `measure_cmd_o`. Measurement controller-ът създава request за съответния qubit и активира pending state. Докато резултатът не пристигне, top-level логиката блокира следващи measurement операции. Когато резултатът пристигне, той се записва във вътрешния measurement state.

`OP_WAIT` генерира `wait_cmd_o`, но основният му ефект е в scheduler-а. При issue на WAIT се зарежда `wait_cnt_q`, който блокира следващите issue операции до изтичане на зададената продължителност. WAIT не заема конкретен qubit busy counter и се разглежда като глобално времево задържане на instruction pipeline-а.

`OP_RESET` се класифицира чрез `reset_cmd_o` и в dependency tracker-а използва target qubit. Така reset операцията участва в busy-counter модела и не може да бъде издадена върху зает target qubit. В текущия RTL модел reset е цифров command сигнал, а не детайлен физически reset процес.

`OP_BRANCH` се класифицира чрез `branch_cmd_o` и се обработва от feedback unit-а. Branch операцията използва flags полето, target qubit-а и measurement state-а, за да определи дали условието е изпълнено. Ако branch е taken, top-level модулът flush-ва operation queue. Ако branch не е taken, queue-ът продължава нормалното си FIFO поведение.

`OP_NOP` се третира като команда без реален command payload. Execution controller-ът активира `nop_cmd_o`, но не активира `command_valid_o`. Това позволява NOP да бъде наблюдавана като issued операция, без да предизвиква gate, measurement или feedback действие.

## 2.7.3 End-to-end MEASURE → result → BRANCH сценарий

Ключовият интеграционен сценарий за текущата архитектура е последователността measurement → measurement result → conditional branch. Той демонстрира връзката между instruction pipeline-а, measurement controller-а, feedback unit-а и top-level flush логиката.

Примерна логическа последователност е:

```text
MEASURE q3
→ measurement_result_i = 1
→ BRANCH if q3 == 1
→ branch_taken_o = 1
```

Първо `MEASURE q3` се приема като инструкция, декодира се, записва се в operation queue и се издава от scheduler-а, когато няма dependency hazard. Execution controller-ът активира `measure_cmd_o`, а measurement controller-ът генерира `measure_request_valid_o` и записва `q3` като pending qubit.

След това външният measurement интерфейс подава `measurement_result_valid_i` и `measurement_result_i`. Measurement controller-ът свързва резултата с pending qubit-а, активира `measurement_valid_o[3]` и записва стойността в `measurement_results_o[3]`. Така measurement state-ът става достъпен за feedback unit-а.

Когато по-късно `BRANCH` инструкцията достигне execution stage-а, feedback unit-ът проверява дали branch е conditional или feedback-related. Ако `target_qubit` сочи към `q3`, а expected bit-ът е `1`, модулът сравнява `measurement_results_o[3]` с очакваната стойност. При съвпадение се активират `feedback_valid_o` и `branch_taken_o`, а `branch_target_o` извежда target стойността от duration полето.

Top-level модулът приема това branch decision събитие и активира `queue_flush`. В резултат всички по-млади инструкции, които са останали в operation queue, се премахват. Това гарантира, че след taken branch контролерът няма да изпълни вече буферирани инструкции от грешния control-flow път.

Този сценарий е проверен в `tb/tb_quantum_controller_top.sv`, където се симулира measurement request, подаване на measurement резултат и последваща branch операция с очаквана стойност. Същият testbench покрива и taken branch flush сценарий, при който инструкция след branch-а не трябва да остане в queue-а.

## 2.7.4 Ограничения на текущия in-order pipeline

Текущият pipeline е in-order и single-issue. Това означава, че във всеки тактов цикъл scheduler-ът може да издаде най-много една операция и винаги разглежда операцията в началото на operation queue. Ако тази операция е блокирана от dependency hazard, WAIT hold или downstream backpressure, следващите операции в queue-а не могат да я изпреварят, дори ако са независими.

Този модел е по-прост и по-подходящ за първоначална RTL реализация, но ограничава потенциалната производителност. При бъдещ out-of-order scheduler контролерът би могъл да разглежда повече от една операция в queue-а, да открива независими операции и да ги издава преди блокираща операция, ако това не нарушава dependency графа. При бъдещ multi-issue модел контролерът би могъл да издава повече от една независима операция в един тактов цикъл.

Текущата архитектура не съдържа instruction memory, program counter, branch target fetch механизъм или branch prediction. Branch target-ът се извежда като сигнал, но самото пренасочване на fetch потока остава извън обхвата на настоящата RTL реализация. Поради това branch логиката трябва да се разглежда като feedback decision и queue flush механизъм, а не като пълна процесорна control-flow подсистема.

Measurement моделът също е опростен. Поддържа се едно pending measurement състояние, което е достатъчно за демонстрация на feedback сценарии, но не покрива едновременно множество измервания с различна латентност. Бъдещо разширение може да добави measurement transaction queue, tag-based резултати или scoreboard за няколко pending measurements.

Тези ограничения са съзнателни и съответстват на целта на текущата глава: да опише стабилна, проверена и проследима RTL архитектура на класически instruction-driven квантов контролер. По-сложните scheduling и control-flow механизми остават като бъдеща работа и могат да бъдат разгледани след изграждане на пълна UVM среда и експериментална методология.

---

# 2.8 Verilator симулационна проверка на RTL

## 2.8.1 Module-level testbench-и

Функционалната проверка на основната RTL архитектура се извършва чрез Verilator testbench-и. За всеки основен модул е създаден отделен testbench, който проверява локалното поведение на модула преди разглеждане на top-level интеграцията. Този подход намалява риска от трудни за локализиране грешки, защото всеки блок се валидира самостоятелно.

Module-level testbench-ите са обобщени в следната таблица.

| Testbench | Проверяван модул | Основни проверявани сценарии |
|---|---|---|
| `tb/tb_qc_pkg.sv` | `rtl/qc_pkg.sv` | Параметри, opcode стойности и instruction field layout |
| `tb/tb_instruction_decoder.sv` | `rtl/instruction_decoder.sv` | Декодиране на полета, valid bit и illegal opcode |
| `tb/tb_operation_queue.sv` | `rtl/operation_queue.sv` | Reset, push, pop, full queue и flush поведение |
| `tb/tb_dependency_tracker.sv` | `rtl/dependency_tracker.sv` | Target/control resource detection и dependency hazards |
| `tb/tb_scheduler.sv` | `rtl/scheduler.sv` | Issue, busy counters, CNOT hazard, backpressure и WAIT hold |
| `tb/tb_execution_controller.sv` | `rtl/execution_controller.sv` | Gate, measure, wait, reset, branch, nop и illegal issue |
| `tb/tb_measurement_controller.sv` | `rtl/measurement_controller.sv` | Measurement request, result storage и unexpected result |
| `tb/tb_feedback_unit.sv` | `rtl/feedback_unit.sv` | Conditional branch, missing measurement и unconditional branch |

Всеки testbench генерира simulation log в `results/simulation_logs/`. В логовете се записват отделните проверени сценарии и финален PASS резултат за съответния модул. Например scheduler testbench-ът съдържа отделни проверки за dependency hazard, backpressure stall и WAIT scheduler hold, а operation queue testbench-ът съдържа отделна проверка за flush поведение.

## 2.8.2 Top-level integration testbench

Основен файл:

```text
tb/tb_quantum_controller_top.sv
```

Top-level integration testbench-ът проверява дали отделните RTL модули работят съгласувано като единен контролер. Той не замества module-level testbench-ите, а ги допълва чрез end-to-end сценарии, при които инструкцията преминава през decoder, queue, scheduler, execution controller, measurement controller и feedback unit.

Основните проверявани top-level сценарии са:

- reset поведение на интегрирания контролер;
- приемане и изпълнение на gate команди;
- measurement request и връщане на measurement резултат;
- conditional feedback branch;
- measurement backpressure при последователни `MEASURE` операции;
- taken branch flush на operation queue;
- invalid opcode поведение.

Особено важни са measurement backpressure и taken branch flush тестовете, защото те проверяват последните control-flow корекции в RTL-а. Measurement backpressure тестът потвърждава, че второ измерване не се издава, докато първото е pending. Taken branch flush тестът потвърждава, че по-млада инструкция, буферирана след branch-а, се премахва от queue-а при `branch_taken_o`.

## 2.8.3 Regression script и simulation logs

Основен script:

```text
scripts/run_verilator.sh
```

Команда:

```bash
./scripts/run_verilator.sh all
```

Regression script-ът автоматизира изпълнението на всички Verilator testbench-и. Това позволява след всяка съществена RTL промяна да се провери целият набор от module-level и top-level тестове с една команда. Този flow е основното симулационно доказателство, че описаната в Глава 2 архитектура съответства на реално работещ RTL код.

Simulation logs се записват в:

```text
results/simulation_logs/
```

Наличните log файлове включват:

```text
tb_qc_pkg.log
tb_instruction_decoder.log
tb_operation_queue.log
tb_dependency_tracker.log
tb_scheduler.log
tb_execution_controller.log
tb_measurement_controller.log
tb_feedback_unit.log
tb_quantum_controller_top.log
```

Последният regression run завършва успешно за всички изброени testbench-и. Това покрива както локалното поведение на модулите, така и top-level сценарии за measurement-feedback, scheduler stall, WAIT hold и branch flush. Тези резултати дават основание реализираната RTL фаза да бъде описана като функционално проверена чрез directed Verilator тестове.

## 2.8.4 Waveform файлове и проследимост към RTL

Освен текстовите simulation logs, testbench flow-ът генерира VCD waveform файлове. Те позволяват визуално проследяване на сигналите във времето и са особено полезни при анализ на pipeline събития като issue, stall, measurement request, feedback decision и queue flush.

Waveform файловете се съхраняват в:

```text
results/waveforms/
```

Наличните waveform артефакти включват:

```text
operation_queue.vcd
dependency_tracker.vcd
scheduler.vcd
execution_controller.vcd
measurement_controller.vcd
feedback_unit.vcd
quantum_controller_top.vcd
```

Тези файлове осигуряват проследимост между RTL кода, testbench stimulus-а и наблюдаваното времево поведение. Например `quantum_controller_top.vcd` може да се използва за проследяване на пълния път от входна инструкция до `command_valid_o`, `measure_request_valid_o`, `feedback_valid_o` и `branch_taken_o`. Scheduler waveform-ът позволява да се наблюдават `qubit_busy_o`, `issue_valid_o`, `queue_pop_o` и stall поведението.

В контекста на дисертацията waveform файловете могат да бъдат използвани като база за фигури или приложения, но самият текст на Глава 2 се опира основно на структурното описание на RTL модулите и на simulation log резултатите.

---

# 2.9 Синтезируемост и Yosys-friendly synthesis flow

## 2.9.1 Синтезируем SystemVerilog subset

Основният RTL в директорията `rtl/` е написан като синхронна SystemVerilog архитектура с регистрови състояния, combinational dependency logic и ясно разделени модули. Използват се конструкции, които са удобни за модулна разработка и бъдеща UVM верификация, включително `package`, `typedef enum`, `typedef struct packed` и `typedef union packed`.

Тези конструкции правят кода по-четим и намаляват риска от несъответствия между модулите, защото instruction format-ът и opcode стойностите се дефинират централизирано. Същевременно конкретната Yosys инсталация, използвана в проекта, няма активна поддръжка чрез `read_slang` и не разполага със `sv2v` flow. Поради това директният синтез на пълната модулна SystemVerilog реализация от `rtl/` не е използван като основен synthesis path на този етап.

Важно е това разграничение да бъде ясно формулирано. Основната RTL архитектура е функционалната и академично описвана реализация. Yosys-friendly вариантът е адаптиран top-level файл за първоначална synthesis smoke проверка в ограниченията на наличния tool flow.

## 2.9.2 Причина за отделен `rtl_synth` вариант

Отделният `rtl_synth` вариант е създаден по практическа причина. Наличният Yosys frontend в използваната среда не обработва директно всички SystemVerilog конструкции, използвани в основния RTL. Основните ограничения са липсата на `read_slang`, липсата на `sv2v` и затрудненията на стандартния frontend с package, typedef, struct и union конструкции.

Поради това е разработен файлът:

```text
rtl_synth/quantum_controller_top_synth.sv
```

Той представя synthesis-friendly версия на top-level контролера, написана в по-плосък SystemVerilog subset. Целта му е да позволи първоначална проверка, че архитектурните идеи могат да бъдат сведени до синтезируема регистрово-комбинационна логика. Този файл не е заместител на основните RTL модули в `rtl/` и не трябва да се представя като отделна функционална архитектура.

В дисертационния текст това означава, че synthesis резултатите трябва да се описват като резултати от Yosys-friendly smoke-test flow, а не като пълен индустриален synthesis, place-and-route или timing sign-off процес.

## 2.9.3 `quantum_controller_top_synth.sv`

Файлът:

```text
rtl_synth/quantum_controller_top_synth.sv
```

съдържа synthesis-friendly top-level описание на контролера. В него са отразени основните архитектурни функции на модулната реализация: instruction decode, operation queue, dependency/busy-counter модел, scheduler issue логика, execution command класификация, measurement pending state, feedback/branch decision и queue flush при taken branch.

Поради целта си този файл използва по-директно представяне на логиката и избягва част от типизираните SystemVerilog конструкции, които се използват в основния RTL. Той е поддържан синхронно с функционалната архитектура, включително последните control-flow корекции за WAIT hold, measurement backpressure, branch in-flight състояние и branch flush.

Ролята на този файл е да служи като минимален synthesis smoke-test top. Ако в бъдеще tool flow-ът бъде разширен с `read_slang` или `sv2v`, по-добрата посока е директен синтез на модулната RTL архитектура от `rtl/`, вместо дългосрочно поддържане на отделна плоска версия.

## 2.9.4 Yosys scripts и synthesis reports

Synthesis flow-ът е автоматизиран чрез следните файлове:

```text
scripts/synth_quantum_controller_top.ys
scripts/run_yosys_synth.sh
results/synthesis_reports/quantum_controller_top_synth_yosys.log
results/synthesis_reports/quantum_controller_top_synth.json
```

Скриптът `scripts/run_yosys_synth.sh` стартира Yosys със synthesis script-а `scripts/synth_quantum_controller_top.ys`. Log файлът се записва в `results/synthesis_reports/quantum_controller_top_synth_yosys.log`, а генерираният JSON netlist се записва в `results/synthesis_reports/quantum_controller_top_synth.json`.

Последният synthesis run завършва успешно. Yosys отчита две предупреждения, свързани със замяна на вътрешни памети с регистри:

```text
Replacing memory \queue_mem with list of registers
Replacing memory \busy_cnt_q with list of registers
```

Тези предупреждения са очаквани за текущия synthesis-friendly модел и не представляват функционална грешка. Те показват, че Yosys преобразува вътрешните масиви към регистрови структури в netlist представянето.

Крайната статистика от synthesis log-а за `quantum_controller_top_synth` включва:

| Метрика | Стойност |
|---|---:|
| Wires | 1216 |
| Wire bits | 4630 |
| Ports | 46 |
| Port bits | 190 |
| Cells | 4065 |

Тези числа трябва да се разглеждат като начална структурна оценка от Yosys smoke-test flow. Те не са окончателна оценка за площ, честота, power или timing, защото текущият flow не включва технология-специфичен place-and-route, timing constraints или power analysis.

## 2.9.5 Ограничения и бъдещо подобрение на synthesis flow

Ограниченията на текущия synthesis flow произтичат главно от tool поддръжката и от ранния етап на проекта. Използваният Yosys flow потвърждава, че основната логика може да бъде представена като синтезируема регистрово-комбинационна структура, но не дава пълна ASIC или FPGA implementation оценка.

Възможни бъдещи подобрения са:

- добавяне на `read_slang` към Yosys flow-а;
- използване на `sv2v` за преобразуване на основния SystemVerilog RTL;
- refactor на част от основния RTL към по-Yosys-friendly subset;
- директен синтез на модулната архитектура от `rtl/`;
- добавяне на timing constraints;
- изпълнение на technology-mapped synthesis;
- сравнение между различни стойности на `QUEUE_DEPTH` и `NUM_QUBITS`;
- извличане на по-точни resource utilization и timing резултати.

До реализиране на тези подобрения резултатите от `rtl_synth/quantum_controller_top_synth.sv` трябва да се използват като начална проверка за синтезируемост, а не като финална експериментална оценка. Подробният анализ на ресурси, производителност и timing принадлежи към Глава 4, след като бъде оформена по-пълна експериментална методология.

---

# 2.10 Обобщение на реализираната RTL архитектура

## 2.10.1 Проследимост между изисквания, модули и тестове

Реализираната RTL архитектура покрива основните системни изисквания, дефинирани в началото на главата. Проследимостта между изискванията, RTL модулите, testbench-ите и резултатите е важна, защото показва, че текстът на дисертацията описва реално съществуваща и проверена имплементация.

| Изискване | RTL модул | Testbench | Резултат |
|---|---|---|---|
| Instruction format | `qc_pkg.sv` | `tb_qc_pkg.sv` | PASS |
| Instruction decode | `instruction_decoder.sv` | `tb_instruction_decoder.sv` | PASS |
| Operation buffering | `operation_queue.sv` | `tb_operation_queue.sv` | PASS |
| Branch flush на queue | `operation_queue.sv`, `quantum_controller_top.sv` | `tb_operation_queue.sv`, `tb_quantum_controller_top.sv` | PASS |
| Dependency tracking | `dependency_tracker.sv` | `tb_dependency_tracker.sv` | PASS |
| In-order scheduling | `scheduler.sv` | `tb_scheduler.sv` | PASS |
| WAIT hold | `scheduler.sv` | `tb_scheduler.sv` | PASS |
| Digital command interface | `execution_controller.sv` | `tb_execution_controller.sv` | PASS |
| Measurement request/result | `measurement_controller.sv` | `tb_measurement_controller.sv` | PASS |
| Measurement backpressure | `quantum_controller_top.sv`, `measurement_controller.sv` | `tb_quantum_controller_top.sv` | PASS |
| Feedback/branch decision | `feedback_unit.sv` | `tb_feedback_unit.sv` | PASS |
| Top-level integration | `quantum_controller_top.sv` | `tb_quantum_controller_top.sv` | PASS |
| Yosys smoke synthesis | `quantum_controller_top_synth.sv` | `run_yosys_synth.sh` | PASS |

Тази таблица може да бъде разширена в следващите етапи с допълнителни UVM tests, coverage metrics и експериментални workloads. На текущия етап тя показва завършеността на базовата RTL фаза и връзката между архитектурните изисквания и наличните доказателства.

## 2.10.2 Ограничения на текущата реализация

Текущата реализация има ясно дефиниран обхват. Тя реализира цифров instruction-driven контролер, но не реализира пълен квантов компютър или физически quantum backend. Основните ограничения са:

- няма физически quantum processor;
- няма analog pulse generation;
- няма моделиране на шум, декохерентност или грешки на физическо ниво;
- scheduler-ът е in-order dependency-aware;
- няма out-of-order issue;
- няма multi-issue;
- няма instruction memory или program counter;
- branch target-ът се извежда като сигнал, но не управлява fetch subsystem;
- поддържа се едно pending measurement състояние;
- Yosys synthesis използва отделен synthesis-friendly top;
- няма timing, power или place-and-route анализ.

Тези ограничения са съвместими с целта на Глава 2. Главата описва реализираната RTL архитектура и не представя бъдещи разширения като вече завършени резултати. В същото време ограниченията очертават ясни посоки за следващи етапи: UVM верификация, по-богати test scenarios, latency анализ, synthesis resource анализ и евентуално разширяване на scheduler-а.

## 2.10.3 Подготовка за UVM верификация

Реализираната RTL архитектура е подходяща база за UVM верификационна среда. Top-level модулът има ясно дефинирани входни и изходни интерфейси, а debug/status сигналите осигуряват добра наблюдаемост върху вътрешното поведение на pipeline-а. Това е важно за бъдещ monitor и scoreboard модел.

Като DUT за UVM средата може да се използва `rtl/quantum_controller_top.sv`. Основният stimulus ще бъде последователност от 32-битови инструкции, а проверката може да наблюдава `issue_*`, `command_*`, measurement и feedback изходите. Очакваните резултати могат да бъдат моделирани чрез reference model, който следи instruction order, busy qubit state, measurement pending state и branch decisions.

Първоначалните Verilator directed tests вече очертават бъдещия UVM test plan. Те могат да бъдат разширени към:

- directed UVM tests за всеки opcode;
- constrained random instruction sequences;
- dependency stress tests;
- queue full и queue flush scenarios;
- measurement-feedback sequences;
- invalid opcode и protocol violation tests;
- algorithmic workloads като Bell, GHZ, Grover-like и random-circuit-sampling-inspired сценарии;
- coverage model за opcode, flags, dependency hazards, stalls, measurement и branch outcomes.

Така Глава 2 завършва с реализирана и симулационно проверена RTL архитектура, а Глава 3 естествено продължава към систематична UVM базирана функционална верификация на същия DUT.

---

# 2.11 Редакторска карта за допълване на Word версията на Глава 2

Този раздел е добавен като практическа карта за синхронизиране на `docs/Дисертация.docx` с настоящия Markdown файл. Той не е задължително да остане като самостоятелен раздел във финалната дисертация. Целта му е да покаже какво трябва да се добави или поправи в Word версията, така че Глава 2 да не остане само с текстово описание на RTL модулите, а да съдържа реални и правилно форматирани SystemVerilog фрагменти.

При последния преглед на `docs/Дисертация.docx` Глава 2 вече съдържа раздел `2.5 RTL имплементация на основните модули` и captions за фрагментите. Основният проблем е, че част от кодовите откъси са вкарани като слят едноредов текст без line breaks, а някои важни фрагменти липсват или не са достатъчно ясно отделени като кодови блокове. Това отслабва проследимостта между дисертационния текст и реалния RTL код.

## 2.11.1 Минимални правила за редакция на кодовите фрагменти в Word

При прехвърляне към `.docx` всеки кодов откъс трябва да бъде форматиран като отделен моноширинен блок, а не като обикновен параграф. Трябва да се запазят:

- line breaks;
- indentation;
- празните редове между логически части на кода;
- името на source файла преди или след caption-а;
- кратко обяснение какво доказва фрагментът.

Неправилен вариант:

```text
assign queue_flush = feedback_valid_o && branch_taken_o;assign instr_ready_o = !queue_full && !queue_flush;assign measurement_issue_blocked = ...
```

Правилен вариант:

```systemverilog
assign queue_flush = feedback_valid_o && branch_taken_o;
assign instr_ready_o = !queue_full && !queue_flush;

assign measurement_issue_blocked =
    measurement_busy_o ||
    (sched_issue_valid && (sched_issue_instr.opcode == OP_MEASURE)) ||
    (command_valid_o && (command_instr.opcode == OP_MEASURE));
```

Това е важно, защото в дисертационен текст кодовият фрагмент не трябва само да присъства формално, а трябва да бъде четим и проверим.

## 2.11.2 Таблица за допълване на фрагментите във Word версията

Следната таблица може да се използва като директна редакторска карта при повторно обновяване на `docs/Дисертация.docx`.

| Word място | Source файл | Какво трябва да се направи | Причина |
|---|---|---|---|
| След caption `Фрагмент 2.1` | `rtl/qc_pkg.sv` | Да се запази кодът, но да се форматира като multi-line моноширинен блок | В момента може да изглежда като слят текст |
| След caption `Фрагмент 2.2` | `rtl/instruction_decoder.sv` | Да се запази `valid_o` и `illegal_o` логиката като multi-line блок | Доказва valid/illegal decode |
| След caption `Фрагмент 2.3` | `rtl/operation_queue.sv` | Да се запази reset/flush/push/pop логиката с line breaks | Доказва branch flush и FIFO поведение |
| След caption `Фрагмент 2.4` | `rtl/dependency_tracker.sv` | Да се запази resource detection и hazard assign логиката | Доказва dependency model |
| След caption `Фрагмент 2.5` | `rtl/scheduler.sv` | Да се запази `can_issue`, `stall_o` и `OP_WAIT` логиката като multi-line блок | Доказва scheduler behavior |
| След caption `Фрагмент 2.6` | `rtl/execution_controller.sv` | Да се добави/провери command classification фрагментът | Доказва digital command interface |
| След caption `Фрагмент 2.7` | `rtl/measurement_controller.sv` | Да се добави реалният pending/result code block, ако липсва | В прегледаната Word версия caption-ът присъства, но кодът може да липсва |
| След caption `Фрагмент 2.8` | `rtl/feedback_unit.sv` | Да се добави реалният conditional/unconditional branch code block, ако липсва | В прегледаната Word версия caption-ът присъства, но кодът може да липсва |
| След caption `Фрагмент 2.9` | `rtl/quantum_controller_top.sv` | Да се форматира top-level protection code като multi-line блок | Доказва queue flush, measurement backpressure и branch blocking |
| След `Фрагмент 2.9` или като `Фрагмент 2.10` | `rtl/quantum_controller_top.sv` | Да се добави branch in-flight register code block | Доказва, че BRANCH остава in-flight до feedback decision |
| След Yosys flow описанието | `scripts/synth_quantum_controller_top.ys` | Да се форматира Yosys script-ът като multi-line блок | В Word изглежда слят като един ред |

## 2.11.3 Допълнителен фрагмент за Execution Controller

В текущия основен текст на Markdown раздел `2.5.6` execution controller-ът е описан подробно, но при финалното Word оформяне е полезно да се включи и кратък реален кодов фрагмент. Той трябва да бъде поставен след текста, който обяснява цифровия command интерфейс.

Caption:

```text
Фрагмент 2.6. Класификация на issued операцията в цифров command интерфейс
```

Source:

```text
rtl/execution_controller.sv
```

Код:

```systemverilog
if (issue_valid_i && issue_ready_o) begin
    unique case (issue_instr_i.opcode)
        OP_NOP: begin
            command_valid_o <= 1'b0;
            command_instr_o <= issue_instr_i;
            nop_cmd_o       <= 1'b1;
        end

        OP_H,
        OP_X,
        OP_Z,
        OP_CNOT: begin
            command_valid_o <= 1'b1;
            command_instr_o <= issue_instr_i;
            gate_cmd_o      <= 1'b1;
        end

        OP_MEASURE: begin
            command_valid_o <= 1'b1;
            command_instr_o <= issue_instr_i;
            measure_cmd_o   <= 1'b1;
        end

        OP_WAIT: begin
            command_valid_o <= 1'b1;
            command_instr_o <= issue_instr_i;
            wait_cmd_o      <= 1'b1;
        end

        OP_RESET: begin
            command_valid_o <= 1'b1;
            command_instr_o <= issue_instr_i;
            reset_cmd_o     <= 1'b1;
        end

        OP_BRANCH: begin
            command_valid_o <= 1'b1;
            command_instr_o <= issue_instr_i;
            branch_cmd_o    <= 1'b1;
        end

        default: begin
            command_valid_o <= 1'b0;
            command_instr_o <= issue_instr_i;
            illegal_issue_o <= 1'b1;
        end
    endcase
end
```

Обяснение за Word текста:

```text
Фрагментът показва, че execution controller-ът не генерира физически импулси, а класифицира issued инструкцията като цифров command тип. Така gate, measurement, wait, reset и branch операциите се отделят към съответните downstream блокове, без да се смесва instruction scheduling логиката с физическо pulse-level управление.
```

## 2.11.4 Фрагмент за Measurement Controller, който трябва да присъства във Word

Caption:

```text
Фрагмент 2.7. Measurement pending състояние и запис на резултата
```

Source:

```text
rtl/measurement_controller.sv
```

Код:

```systemverilog
assign command_ready_o    = !pending_q;
assign measurement_busy_o = pending_q;

if (command_valid_i && command_ready_o) begin
    if (command_instr_i.opcode == OP_MEASURE) begin
        pending_q               <= 1'b1;
        pending_qubit_q         <= command_instr_i.target_qubit;
        measure_request_valid_o <= 1'b1;
        measure_qubit_o         <= command_instr_i.target_qubit;
    end
end

if (measurement_result_valid_i) begin
    if (pending_q) begin
        pending_q <= 1'b0;
        measurement_valid_o[pending_qubit_q]   <= 1'b1;
        measurement_results_o[pending_qubit_q] <= measurement_result_i;
    end else begin
        unexpected_result_o <= 1'b1;
    end
end
```

Обяснение за Word текста:

```text
Фрагментът показва как measurement controller-ът свързва заявката за измерване с по-късно пристигащ класически резултат. `pending_q` пази факта, че има незавършено измерване, `pending_qubit_q` пази кубита, а при пристигане на резултат се обновяват `measurement_valid_o` и `measurement_results_o`. Ако резултат пристигне без pending заявка, се активира `unexpected_result_o`.
```

## 2.11.5 Фрагмент за Feedback Unit, който трябва да присъства във Word

Caption:

```text
Фрагмент 2.8. Conditional и unconditional branch решение във feedback unit-а
```

Source:

```text
rtl/feedback_unit.sv
```

Код:

```systemverilog
assign conditional_branch = command_instr_i.flags[FLAG_CONDITIONAL_BIT] |
                            command_instr_i.flags[FLAG_FEEDBACK_BIT];
assign expected_value     = command_instr_i.flags[FLAG_EXPECTED_BIT];

if (command_valid_i && branch_cmd_i &&
    command_instr_i.opcode == OP_BRANCH &&
    command_instr_i.flags[FLAG_VALID_BIT]) begin

    feedback_valid_o <= 1'b1;
    branch_target_o  <= command_instr_i.duration;

    if (conditional_branch) begin
        if (selected_valid) begin
            condition_checked_o <= 1'b1;
            feedback_value_o    <= selected_result;
            branch_taken_o      <= (selected_result == expected_value);
        end else begin
            missing_measurement_o <= 1'b1;
            branch_taken_o        <= 1'b0;
        end
    end else begin
        branch_taken_o <= 1'b1;
    end
end
```

Обяснение за Word текста:

```text
Фрагментът доказва как feedback unit-ът различава условен и безусловен branch. При условен branch решението зависи от наличен measurement резултат и от очакваната стойност във flags полето. При липсващ резултат branch не се взема и се активира `missing_measurement_o`; при безусловен branch `branch_taken_o` се активира директно.
```

## 2.11.6 Допълнителен фрагмент за branch in-flight състояние

В Word версията е полезно да се добави отделен кратък фрагмент за `branch_inflight_q`, защото той обяснява защо top-level контролерът не допуска нов branch преди предходното feedback решение да приключи.

Caption:

```text
Фрагмент 2.10. Branch in-flight регистрово състояние в top-level модула
```

Source:

```text
rtl/quantum_controller_top.sv
```

Код:

```systemverilog
if (feedback_valid_o) begin
    branch_inflight_q <= 1'b0;
end

if (sched_issue_valid && (sched_issue_instr.opcode == OP_BRANCH)) begin
    branch_inflight_q <= 1'b1;
end
```

Обяснение за Word текста:

```text
Този регистър моделира факта, че branch операцията остава активна до получаване на feedback decision. Докато `branch_inflight_q` е активен, top-level backpressure логиката блокира издаването на нов branch. Това предотвратява припокриване на branch решения в текущия in-order pipeline.
```

Ако този фрагмент се добави като `Фрагмент 2.10`, тогава Yosys script фрагментът в раздел `2.9.4` трябва да стане `Фрагмент 2.11`.

## 2.11.7 Форматиране на Yosys script фрагмента

В Word версията Yosys script-ът трябва да бъде форматиран като multi-line блок, защото в слят едноредов вид не показва реалната последователност на flow-а.

Caption:

```text
Фрагмент 2.11. Основна последователност от команди в Yosys synthesis script-а
```

Source:

```text
scripts/synth_quantum_controller_top.ys
```

Код:

```tcl
read_verilog -sv rtl_synth/quantum_controller_top_synth.sv

hierarchy -check -top quantum_controller_top_synth

proc
opt
fsm
opt
memory
opt
techmap
opt

stat

write_json results/synthesis_reports/quantum_controller_top_synth.json
```

Обяснение за Word текста:

```text
Фрагментът показва, че текущият synthesis flow извършва базово четене на synthesis-friendly SystemVerilog top, hierarchy проверка, process lowering, оптимизации, FSM обработка, memory обработка, technology mapping, статистика и извеждане на JSON netlist. Това е smoke-test synthesis flow, а не пълен timing sign-off.
```

## 2.11.8 Проверка след обновяване на Word версията

След като Word документът бъде обновен от този Markdown, трябва да се провери следното:

| Проверка | Очакван резултат |
|---|---|
| Всеки caption `Фрагмент 2.x` има реален кодов блок след себе си | Да |
| Кодът не е слят в един ред | Да |
| Фрагментите имат source file препратка | Да |
| `measurement_controller.sv` фрагментът присъства | Да |
| `feedback_unit.sv` фрагментът присъства | Да |
| `branch_inflight_q` фрагментът присъства или е обяснен в top-level фрагмента | Да |
| Yosys script-ът е multi-line | Да |
| Текстът не твърди директен Yosys синтез на основния `rtl/` код | Да |
| Ограниченията на RTL реализацията остават ясно описани | Да |

Ако тези проверки са изпълнени, Глава 2 ще бъде значително по-добре защитена като дисертационен текст, защото всяко важно архитектурно твърдение ще има не само словесно обяснение, но и кратко реално доказателство от кода.
