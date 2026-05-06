# RTL Progress Context – Instruction-driven Quantum Controller

## 1. Обща цел на разработката

Текущият RTL проект е част от дисертационна разработка на instruction-driven RTL контролер за управление на абстрактни квантови операции.

Целта на контролера е да приема 32-битови инструкции, описващи квантови операции, да ги декодира, да ги поставя в опашка, да анализира зависимости между операции върху кубити и да издава операции за изпълнение само когато необходимите кубити са свободни.

Към момента е реализиран първи минимален работещ RTL pipeline:

raw 32-bit instruction
→ instruction_decoder
→ operation_queue
→ dependency-aware scheduler
→ issued quantum operation

Това е минимален RTL прототип, а не пълният финален контролер. Той служи като основа за Глава 2 от дисертацията и за следващите RTL модули.

---

## 2. Текуща структура на проекта

Основната директория е:

~/quantum_controller

Текущата структура е приблизително:

quantum_controller/
├── docs/
│   └── rtl_progress_context.md
├── results/
│   ├── simulation_logs/
│   ├── synthesis_reports/
│   └── waveforms/
├── rtl/
│   ├── qc_pkg.sv
│   ├── instruction_decoder.sv
│   ├── operation_queue.sv
│   ├── scheduler.sv
│   ├── quantum_controller_top.sv
│   └── simple_and.sv
├── scripts/
│   └── run_verilator.sh
├── tb/
│   ├── tb_qc_pkg.sv
│   ├── tb_instruction_decoder.sv
│   ├── tb_operation_queue.sv
│   ├── tb_scheduler.sv
│   ├── tb_quantum_controller_top.sv
│   └── tb_simple_and.sv
└── uvm/

---

## 3. Използвани инструменти

Средата е под Windows + WSL2 Ubuntu.

Проверени инструменти:

- WSL2: Ubuntu running with VERSION 2
- Verilator: 5.049 devel
- Yosys: 0.64+
- Python: 3.12.3
- Git: използва се за version control

---

## 4. Реализирани RTL файлове

### 4.1 rtl/simple_and.sv

Това е първоначален тестов SystemVerilog модул, използван само за проверка на средата.

Функция:

- Приема два входа: a и b
- Извежда y = a & b

Този файл няма архитектурно значение за квантовия контролер. Използван е само за потвърждение, че Verilator, testbench и waveform flow работят.

Свързан testbench:

tb/tb_simple_and.sv

---

### 4.2 rtl/qc_pkg.sv

Това е основният SystemVerilog package за проекта.

Функция:

- Дефинира глобални параметри на архитектурата
- Дефинира ширината на инструкцията
- Дефинира opcode encoding
- Дефинира структурата на декодирана инструкция
- Дефинира union представяне между raw 32-bit instruction и decoded fields

Основни параметри:

INSTR_W      = 32
OPCODE_W     = 4
QUBIT_ID_W   = 4
DURATION_W   = 12
FLAGS_W      = 4
RESERVED_W   = 4
MAX_QUBITS   = 16

Instruction format:

[31:28] opcode
[27:24] target_qubit
[23:20] control_qubit
[19:8]  duration
[7:4]   flags
[3:0]   reserved

Поддържани opcode-и:

OP_NOP     = 4'h0
OP_H       = 4'h1
OP_X       = 4'h2
OP_Z       = 4'h3
OP_CNOT    = 4'h4
OP_MEASURE = 4'h5
OP_WAIT    = 4'h6
OP_RESET   = 4'h7
OP_BRANCH  = 4'h8
OP_INVALID = 4'hF

Основни типове:

- qc_opcode_e
- qc_flags_t
- qc_instr_fields_t
- qc_instr_t

Значение за архитектурата:

Този файл е основата на instruction-driven модела. Всички следващи RTL модули използват типовете и параметрите от него.

Свързан testbench:

tb/tb_qc_pkg.sv

---

### 4.3 rtl/instruction_decoder.sv

Този модул декодира входна 32-битова инструкция.

Входове:

- instr_i [31:0]

Изходи:

- opcode_o
- target_qubit_o
- control_qubit_o
- duration_o
- flags_o
- valid_o
- illegal_o

Функция:

- Приема raw 32-bit instruction
- Използва qc_instr_t union от qc_pkg.sv
- Разделя инструкцията на полета
- Извежда opcode, target qubit, control qubit, duration и flags
- flags[3] се използва като valid bit
- Проверява дали opcode е позволен
- При непознат opcode активира illegal_o

Поддържани валидни opcode-и:

- OP_NOP
- OP_H
- OP_X
- OP_Z
- OP_CNOT
- OP_MEASURE
- OP_WAIT
- OP_RESET
- OP_BRANCH

Всички други opcode-и се считат за illegal.

Свързан testbench:

tb/tb_instruction_decoder.sv

Тестовете проверяват:

- H q2, duration 4
- CNOT q1, q3, duration 8
- invalid opcode 4'hF

---

### 4.4 rtl/operation_queue.sv

Това е FIFO опашка за декодирани операции.

Параметър:

DEPTH = 4 по подразбиране

Входове:

- clk_i
- rst_ni
- push_i
- instr_i
- pop_i

Изходи:

- full_o
- instr_o
- empty_o
- count_o

Функция:

- Съхранява декодирани инструкции от тип qc_instr_fields_t
- Поддържа push/pop логика
- Поддържа FIFO ред
- Дава информация дали е full или empty
- Дава текущ брой елементи чрез count_o

Вътрешни елементи:

- mem_q [DEPTH]
- wr_ptr_q
- rd_ptr_q
- count_q

Значение за архитектурата:

Тази опашка стои между decoder-а и scheduler-а. Тя позволява входните инструкции да се буферират, преди scheduler-ът да реши кога могат да бъдат издадени за изпълнение.

Свързан testbench:

tb/tb_operation_queue.sv

Тестовете проверяват:

- reset състояние
- push на H q0
- push на CNOT q1,q3
- FIFO ред
- pop операции
- full queue състояние

---

### 4.5 rtl/scheduler.sv

Това е първият базов dependency-aware scheduler.

Параметър:

NUM_QUBITS = MAX_QUBITS

Входове:

- clk_i
- rst_ni
- instr_valid_i
- instr_i

Изходи:

- queue_pop_o
- issue_valid_o
- issue_instr_o
- stall_o
- qubit_busy_o

Функция:

Scheduler-ът гледа текущата инструкция от operation queue и решава дали тя може да бъде издадена.

Основна логика:

- Еднокубитни операции използват target_qubit
- CNOT използва target_qubit и control_qubit
- Ако необходимият кубит е зает, scheduler-ът активира stall_o
- Ако няма hazard, scheduler-ът активира queue_pop_o и issue_valid_o
- При issue операцията се записва в issue_instr_o
- Съответните кубити се маркират като busy за duration цикли
- busy counter-ите се намаляват всеки clock cycle

Поддържани зависимости:

- H/X/Z/MEASURE/RESET използват target_qubit
- CNOT използва target_qubit и control_qubit
- Ако операция използва зает кубит, тя не се издава

Ограничения на текущата версия:

- Scheduler-ът е базов
- Работи само с първата инструкция от опашката
- Все още няма out-of-order scheduling
- Няма отделен dependency_tracker модул
- WAIT и BRANCH не са напълно развити
- Няма реален execution_controller

Свързан testbench:

tb/tb_scheduler.sv

Тестовете проверяват:

- issue на H q0
- issue на независима X q1, докато q0 е busy
- busy counter clear
- stall при CNOT q1,q0, когато q0 е busy
- issue на CNOT след освобождаване на зависимостта

---

### 4.6 rtl/quantum_controller_top.sv

Това е текущият top-level RTL skeleton.

Параметри:

QUEUE_DEPTH = 4
NUM_QUBITS  = MAX_QUBITS

Входове:

- clk_i
- rst_ni
- instr_i
- instr_valid_i

Изходи:

- instr_ready_o
- issue_valid_o
- issue_opcode_o
- issue_target_qubit_o
- issue_control_qubit_o
- issue_duration_o
- issue_flags_o
- scheduler_stall_o
- illegal_instr_o
- queue_count_o
- qubit_busy_o

Интегрирани модули:

- instruction_decoder
- operation_queue
- scheduler

Функционален поток:

1. Входна 32-битова инструкция постъпва през instr_i.
2. instruction_decoder я разделя на полета.
3. Ако инструкцията е валидна и не е illegal, тя се записва в operation_queue.
4. operation_queue подава първата чакаща инструкция към scheduler.
5. scheduler проверява дали нужните кубити са свободни.
6. Ако няма hazard, scheduler активира issue_valid_o и издава операцията.
7. Top-level изкарва issue полетата на изходите.
8. Ако има illegal opcode, top-level активира illegal_instr_o.

Значение:

Това е първият работещ RTL pipeline на квантовия контролер.

Свързан testbench:

tb/tb_quantum_controller_top.sv

Тестовете проверяват:

- reset състояние
- H q0 влиза в queue и се issue-ва
- X q1 се issue-ва независимо, докато q0 може да е busy
- CNOT q2,q0 изчаква, ако q0 е busy
- CNOT се issue-ва след освобождаване на зависимостта
- invalid opcode не влиза в queue

---

## 5. Реализирани testbench файлове

### 5.1 tb/tb_simple_and.sv

Първоначален тест за simple_and.sv.

Проверява:

- 0 & 0 = 0
- 0 & 1 = 0
- 1 & 0 = 0
- 1 & 1 = 1

Генерира waveform:

results/waveforms/simple_and.vcd

---

### 5.2 tb/tb_qc_pkg.sv

Проверява package-а qc_pkg.sv.

Проверява:

- създаване на instruction чрез qc_instr_t
- задаване на OP_H
- target_qubit
- duration
- flags
- raw instruction representation

Очакван край:

qc_pkg test PASSED

---

### 5.3 tb/tb_instruction_decoder.sv

Проверява instruction_decoder.sv.

Проверява:

- H q2
- CNOT q1,q3
- invalid opcode

Очакван край:

instruction_decoder test PASSED

---

### 5.4 tb/tb_operation_queue.sv

Проверява operation_queue.sv.

Проверява:

- reset
- push
- pop
- FIFO ред
- full queue

Очакван край:

operation_queue test PASSED

---

### 5.5 tb/tb_scheduler.sv

Проверява scheduler.sv.

Проверява:

- issue на операция без hazard
- независима операция върху друг кубит
- dependency hazard
- stall
- освобождаване на busy counter-и
- CNOT с target и control qubit

Очакван край:

scheduler test PASSED

---

### 5.6 tb/tb_quantum_controller_top.sv

Проверява интегрирания top-level pipeline.

Проверява:

- decoder → queue → scheduler
- issue на H q0
- issue на X q1
- stall/изчакване при CNOT зависимост
- invalid opcode detection

Очакван край:

quantum_controller_top scheduler integration test PASSED

---

## 6. Simulation script

### scripts/run_verilator.sh

Това е helper script за стартиране на Verilator тестове.

Поддържани тестове:

- tb_qc_pkg
- tb_instruction_decoder
- tb_operation_queue
- tb_scheduler
- tb_quantum_controller_top
- all

Примери:

./scripts/run_verilator.sh tb_quantum_controller_top

./scripts/run_verilator.sh all

Скриптът:

- компилира избрания testbench
- стартира симулацията
- записва log файл в results/simulation_logs/
- генерира waveform файлове в results/waveforms/, ако testbench-ът съдържа $dumpfile/$dumpvars

---

## 7. Как се стартират тестовете

Стартиране на всички тестове:

./scripts/run_verilator.sh all

Стартиране само на top-level теста:

./scripts/run_verilator.sh tb_quantum_controller_top

Проверка на логовете:

ls -l results/simulation_logs/

Проверка на waveform файловете:

ls -l results/waveforms/

Отваряне на waveform:

gtkwave results/waveforms/quantum_controller_top.vcd

---

## 8. Текущ статус

Към момента е реализирана стабилна минимална RTL версия.

Готови RTL блокове:

- qc_pkg.sv
- instruction_decoder.sv
- operation_queue.sv
- scheduler.sv
- quantum_controller_top.sv

Готови testbench-и:

- tb_qc_pkg.sv
- tb_instruction_decoder.sv
- tb_operation_queue.sv
- tb_scheduler.sv
- tb_quantum_controller_top.sv

Готов script:

- scripts/run_verilator.sh

Преминати тестове:

- qc_pkg test
- instruction_decoder test
- operation_queue test
- scheduler test
- quantum_controller_top scheduler integration test

---

## 9. Какво е важно за бъдещ агент

Бъдещ агент трябва да знае следното:

1. Проектът е част от дисертация за instruction-driven RTL квантов контролер.
2. Не се реализира реален квантов процесор.
3. Не се генерират реални аналогови RF импулси.
4. Квантовият процесор се моделира абстрактно.
5. Фокусът е върху класически RTL контролер.
6. Текущият pipeline вече работи:
   raw instruction → decoder → queue → scheduler → issued operation
7. Следващата работа трябва да запази връзката с Глава 2 на дисертацията.
8. Не трябва да се пишат нови големи RTL модули без да се документира архитектурната логика в текста.
9. Следващите вероятни RTL модули са:
   - dependency_tracker.sv
   - execution_controller.sv
   - measurement_controller.sv
   - feedback_unit.sv
10. Преди тях е препоръчително да се върнем към текста на Глава 2.

---

## 10. Връзка с Глава 2

Текущият код директно подпомага следните раздели от Глава 2:

2.1.2 Дефиниране на instruction format

Свързан код:

- qc_pkg.sv
- tb_qc_pkg.sv

2.1.3 Общ архитектурен модел

Свързан код:

- quantum_controller_top.sv

2.2 Блокова архитектура на контролера

Свързан код:

- instruction_decoder.sv
- operation_queue.sv
- scheduler.sv
- quantum_controller_top.sv

2.2.2 Основни модули

Модули за описание:

- Instruction Decoder
- Operation Queue
- Scheduler
- Top-level Controller

2.2.3 Поток на данни

Текущ data flow:

raw instruction
→ decoded fields
→ queued operation
→ scheduled operation
→ issued operation

2.2.4 Контролен поток

Текущ control flow:

instr_valid_i / instr_ready_o
→ queue_push
→ queue_pop
→ issue_valid_o
→ scheduler_stall_o
→ illegal_instr_o

2.3 Математическа формализация на scheduler

Текущият scheduler може да бъде използван като начална основа за формализиране на зависимости между операции, като операции върху един и същ кубит не могат да се изпълняват едновременно.

2.4 RTL имплементация

Текущите RTL файлове са първият материал за този раздел.

---

## 11. Следващ препоръчителен план

Препоръчителният следващ план е:

1. Да се документира текущият RTL pipeline в Глава 2.
2. Да се напише академичен текст за:
   - 2.1.2 Instruction format
   - 2.1.3 Общ архитектурен модел
   - 2.2 Блокова архитектура
   - 2.2.2 Основни модули
   - 2.2.3 Поток на данни
   - 2.2.4 Контролен поток
3. След това да се продължи с RTL:
   - dependency_tracker.sv
   - execution_controller.sv
   - measurement_controller.sv
   - feedback_unit.sv
4. След всеки модул да се добавя testbench.
5. След стабилизиране на RTL модулите да се премине към UVM среда.

---

## 12. Git статус

Кодът трябва да е записан с commit-и след всяка значима стъпка.

Препоръчително е след създаване на този документ да се изпълни:

git status
git add docs/rtl_progress_context.md
git commit -m "Document current RTL progress and pipeline context"

---

## 13. Кратко резюме за нов чат или бъдещ агент

Разработва се instruction-driven RTL квантов контролер за дисертация. Към момента е реализиран минимален работещ RTL pipeline: 32-битова инструкция се декодира чрез instruction_decoder, поставя се в operation_queue, след което dependency-aware scheduler проверява дали target/control кубитите са свободни и издава операцията чрез issue интерфейс. Реализирани са qc_pkg.sv, instruction_decoder.sv, operation_queue.sv, scheduler.sv и quantum_controller_top.sv, както и testbench-и за всеки модул. Всички тестове се стартират чрез scripts/run_verilator.sh all. Следващата логична стъпка е временно връщане към писането на Глава 2, за да се документират instruction format, общият архитектурен модел, блоковата архитектура, data flow и control flow, преди да се добавят нови RTL модули като dependency_tracker, execution_controller, measurement_controller и feedback_unit.

