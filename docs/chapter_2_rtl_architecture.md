# ГЛАВА 2: RTL архитектура на квантовия контролер

# 2.1 Архитектурна концепция

След формулирането на научния проблем и анализа на съществуващите подходи за управление на квантови системи настоящата глава представя реализираната RTL архитектура на класически контролер за квантови операции. За разлика от теоретичния обзор в Глава 1, тук фокусът е върху конкретната цифрова реализация, разработените SystemVerilog модули, вътрешния поток на данни, управляващите състояния и доказателствата за функционална коректност, получени чрез симулация.

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
