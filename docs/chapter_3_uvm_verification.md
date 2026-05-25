# ГЛАВА 3: UVM базирана верификационна среда

## 3.0 Статус и правило за попълване

Този Markdown файл е работният технически източник за бъдещото финално писане на Глава 3 от дисертацията. Той трябва да се попълва постепенно, паралелно с реалната разработка на UVM средата в директорията `uvm/`.

Основното правило остава implementation-first:

```text
първо се реализира UVM код
→ след това се проверява/симулира, доколкото наличният toolchain позволява
→ след това се документира тук с реални препратки и кратки кодови фрагменти
→ едва след това се описва като завършен резултат във финалната дисертация
```

Към текущия момент е започната Phase C от работния план. Реализирана е началната UVM инфраструктура за transaction/sequence item, stimulus generation, driver/interface слой, passive monitor observation слой и първи scoreboard/reference модел:

```text
uvm/qc_uvm_pkg.sv
uvm/qc_sequence_item.sv
uvm/qc_observation_item.sv
uvm/qc_sequencer.sv
uvm/qc_sequences.sv
uvm/qc_if.sv
uvm/qc_driver.sv
uvm/qc_monitor.sv
uvm/qc_scoreboard.sv
```

Все още не са реализирани coverage collector, UVM agent/environment, UVM tests или UVM top-level testbench. Sequencer-ът, sequence класовете, virtual interface-ът, driver-ът, monitor-ът и scoreboard-ът вече съществуват като UVM код, но все още не са изпълнявани срещу DUT като пълна UVM симулация, защото липсват agent/env/test top и UVM-capable simulator flow.

---

## 3.0.1 Контролен списък за финалното писане на Глава 3

Тази таблица отговаря директно на изискванията за информация, която трябва да присъства в Markdown файла и после във финалното писане на главата.

| № | Изисквана информация | Текущ статус | Къде се попълва |
|---:|---|---|---|
| 1 | Каква UVM среда е реализирана | Започната е UVM среда; налични са package, transaction item, observation item, sequencer, sequences, interface, driver, monitor и scoreboard | Раздели 3.2, 3.4 и 3.5 |
| 2 | Кои файлове са създадени в `uvm/` | Създадени са `qc_uvm_pkg.sv`, `qc_sequence_item.sv`, `qc_observation_item.sv`, `qc_sequencer.sv`, `qc_sequences.sv`, `qc_if.sv`, `qc_driver.sv`, `qc_monitor.sv` и `qc_scoreboard.sv` | Раздел 3.2 |
| 3 | Как DUT е свързан към testbench-а | Частично реализирано чрез `qc_if.sv`; top-level UVM testbench още предстои | Раздел 3.3 |
| 4 | Какво съдържа transaction/sequence item | Реализирано в `uvm/qc_sequence_item.sv` | Раздел 3.4 |
| 5 | Как работят sequencer, driver, monitor, scoreboard и coverage | Sequencer, sequences, driver, monitor и scoreboard са реализирани; coverage предстои | Раздел 3.5 |
| 6 | Какви directed tests са реализирани | Има directed sequence класове; executable UVM tests още няма | Раздел 3.6.1 |
| 7 | Какви constrained-random/stress tests са реализирани | Има random и dependency stress sequence класове; още не са изпълнявани | Раздел 3.6.2 |
| 8 | Какви algorithmic workloads са реализирани | Има Bell, GHZ и Grover-like sequence класове; още не са изпълнявани | Раздел 3.6.3 |
| 9 | Как се пускат симулациите | RTL baseline се пуска с `scripts/run_verilator.sh`; UVM simulation script още не е реализиран | Раздел 3.7 |
| 10 | Какви log/waveform/coverage резултати има | Налични са RTL Verilator logs/waves; UVM logs/waves/coverage още няма | Раздел 3.8 |
| 11 | Какви ограничения има текущата UVM среда | Описани са текущите ограничения и toolchain липси | Раздел 3.9 |

---

# 3.1 Методология на верификацията

Целта на Глава 3 е да опише UVM базирана верификационна среда за вече реализирания RTL квантов контролер. За разлика от Verilator testbench-ите в директорията `tb/`, които проверяват отделни модули и няколко top-level сценария, UVM средата трябва да осигури по-систематична проверка чрез transaction-driven stimulus, reusable sequences, monitor-based observation, scoreboard сравнение и functional coverage.

Основният DUT за UVM верификацията е:

```text
rtl/quantum_controller_top.sv
```

UVM средата трябва да работи върху основната модулна RTL реализация в `rtl/`, а не върху synthesis-friendly варианта в `rtl_synth/`. Причината е, че Глава 3 верифицира функционалното поведение на архитектурата, докато `rtl_synth/quantum_controller_top_synth.sv` служи за отделен Yosys smoke test в Глава 4.

Предвиденият verification подход е:

1. Driver-ът подава 32-битови инструкции към `instr_i` чрез ready/valid протокол.
2. При measurement сценарии driver-ът или отделен responder подава `measurement_result_valid_i` и `measurement_result_i` след наблюдавана measurement request операция.
3. Monitor-ът наблюдава входния instruction интерфейс, issue интерфейса, command интерфейса, measurement интерфейса и feedback/branch изходите.
4. Scoreboard-ът сравнява очакваното поведение с наблюдаваните DUT изходи.
5. Coverage collector-ът отчита opcode покритие, flag комбинации, dependency/stall сценарии, measurement-feedback сценарии, branch taken/not-taken сценарии и queue/backpressure състояния.

Към момента тази методология е заложена в плана, като реално имплементирани са transaction/sequence item слой, observation item слой, sequencer, начални sequence класове, virtual interface, driver, monitor и scoreboard. Следващият липсващ слой е coverage и UVM agent/environment, които трябва да свържат компонентите в executable UVM среда и да дадат количествена оценка на покритието.

---

# 3.2 Реализирана UVM структура към момента

Към момента директорията `uvm/` съдържа следните файлове:

| Файл | Статус | Роля |
|---|---|---|
| `uvm/qc_uvm_pkg.sv` | Реализиран | Общ UVM package, който импортира `uvm_pkg`, `qc_pkg` и включва UVM класовете |
| `uvm/qc_sequence_item.sv` | Реализиран | Transaction/sequence item за генериране на instruction-level stimulus |
| `uvm/qc_observation_item.sv` | Реализиран | Observation transaction за monitor, scoreboard и coverage |
| `uvm/qc_sequencer.sv` | Реализиран | Типизиран UVM sequencer за `qc_sequence_item` |
| `uvm/qc_sequences.sv` | Реализиран | Directed, random, stress и algorithmic sequence класове |
| `uvm/qc_if.sv` | Реализиран | SystemVerilog interface за DUT сигналите, driver/monitor clocking blocks и DUT modport |
| `uvm/qc_driver.sv` | Реализиран | UVM driver, който управлява instruction ready/valid интерфейса и measurement response входа |
| `uvm/qc_monitor.sv` | Реализиран | Passive UVM monitor, който публикува наблюдения през analysis port |
| `uvm/qc_scoreboard.sv` | Реализиран | Reference checking компонент върху `qc_observation_item` потока |

Все още не са създадени:

```text
uvm/qc_coverage.sv
uvm/qc_agent.sv
uvm/qc_env.sv
uvm/qc_base_test.sv
uvm/qc_directed_tests.sv
uvm/qc_random_tests.sv
uvm/tb_qc_uvm_top.sv
```

Тези файлове следват Phase C от работния план и трябва да се добавят постепенно.

## Кодов фрагмент 3.1 – UVM package файл

Файлът `uvm/qc_uvm_pkg.sv` централизира UVM класовете и ги свързва с RTL package-а `qc_pkg`.

```systemverilog
package qc_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import qc_pkg::*;

    `include "qc_sequence_item.sv"
    `include "qc_observation_item.sv"
    `include "qc_sequencer.sv"
    `include "qc_sequences.sv"
    `include "qc_driver.sv"
    `include "qc_monitor.sv"
    `include "qc_scoreboard.sv"

endpackage : qc_uvm_pkg
```

Тази структура означава, че UVM класовете не дефинират собствен instruction format. Вместо това те използват същите параметри, opcode enum-и и field width дефиниции от `rtl/qc_pkg.sv`, които се използват и от DUT. Файлът `uvm/qc_if.sv` не е include-нат в package-а, защото SystemVerilog interface е design element и трябва да се компилира отделно преди `uvm/qc_uvm_pkg.sv`.

---

# 3.3 DUT интерфейс и свързване към UVM testbench

Част от свързването на DUT към UVM testbench вече е реализирана чрез `uvm/qc_if.sv`. Този SystemVerilog interface описва сигналите на `rtl/quantum_controller_top.sv`, предоставя clocking block за driver-а, clocking block за monitor-а и `dut` modport за бъдещия top-level UVM testbench.

Основните входове за stimulus са:

```text
clk_i
rst_ni
instr_i
instr_valid_i
measurement_result_valid_i
measurement_result_i
```

Основните изходи за наблюдение са:

```text
instr_ready_o
issue_valid_o
issue_opcode_o
issue_target_qubit_o
issue_control_qubit_o
issue_duration_o
issue_flags_o
command_valid_o
command_opcode_o
command_target_qubit_o
command_control_qubit_o
command_duration_o
command_flags_o
gate_cmd_o
measure_cmd_o
wait_cmd_o
reset_cmd_o
branch_cmd_o
nop_cmd_o
measure_request_valid_o
measure_qubit_o
measurement_busy_o
measurement_result_out_valid_o
measurement_result_qubit_o
measurement_result_value_o
measurement_valid_o
measurement_results_o
feedback_valid_o
branch_taken_o
branch_target_o
scheduler_stall_o
illegal_instr_o
illegal_issue_o
queue_count_o
qubit_busy_o
```

## Кодов фрагмент 3.2 – DUT ready/valid instruction интерфейс

От `rtl/quantum_controller_top.sv`:

```systemverilog
input  logic [INSTR_W-1:0]      instr_i,
input  logic                    instr_valid_i,
output logic                    instr_ready_o,

input  logic                    measurement_result_valid_i,
input  logic                    measurement_result_i,
```

Реализираният UVM driver подава `instr_i` само когато sequence item е наличен и DUT приема инструкция чрез `instr_ready_o`. За measurement сценарии driver-ът използва metadata от `qc_sequence_item`, изчаква `measure_request_valid_o` и след зададен latency подава `measurement_result_valid_i` и `measurement_result_i`.

Планираното UVM свързване е:

```text
qc_sequence_item
→ qc_sequencer
→ qc_driver
→ virtual interface
→ quantum_controller_top
→ qc_monitor
→ qc_observation_item
→ scoreboard + coverage
```

SystemVerilog interface-ът, driver-ът, monitor-ът и scoreboard-ът вече са реализирани. Следващата стъпка е coverage и UVM agent/env слой, който да свърже driver-а със sequencer-а, monitor-а, scoreboard-а и coverage collector-а.

## Кодов фрагмент 3.3 – Основни DUT сигнали в `qc_if.sv`

Файлът `uvm/qc_if.sv` създава обща UVM видимост към входните и изходните DUT сигнали.

```systemverilog
interface qc_if #(
    parameter int QUEUE_DEPTH = 4,
    parameter int NUM_QUBITS  = qc_pkg::MAX_QUBITS
) (
    input logic clk_i
);

    import qc_pkg::*;

    logic                    rst_ni;
    logic [INSTR_W-1:0]      instr_i;
    logic                    instr_valid_i;
    logic                    instr_ready_o;

    logic                    measurement_result_valid_i;
    logic                    measurement_result_i;

    logic                    command_valid_o;
    qc_opcode_e              command_opcode_o;
    logic [QUBIT_ID_W-1:0]   command_target_qubit_o;
    logic [DURATION_W-1:0]   command_duration_o;
```

Тук са показани само част от сигналите. Реалният interface съдържа и issue, command classification, measurement, feedback, status и debug сигналите.

## Кодов фрагмент 3.4 – Driver и monitor clocking blocks

`qc_if.sv` разделя driver достъпа и monitor достъпа чрез отделни clocking blocks.

```systemverilog
clocking drv_cb @(posedge clk_i);
    default input #1step output #1ns;

    output rst_ni;
    output instr_i;
    output instr_valid_i;
    output measurement_result_valid_i;
    output measurement_result_i;

    input  instr_ready_o;
    input  measure_request_valid_o;
    input  measure_qubit_o;
    input  measurement_busy_o;
    input  feedback_valid_o;
    input  branch_taken_o;
endclocking

clocking mon_cb @(posedge clk_i);
    default input #1step output #1ns;

    input rst_ni;
    input instr_i;
    input instr_valid_i;
    input instr_ready_o;
    input command_valid_o;
    input command_opcode_o;
    input measure_request_valid_o;
    input feedback_valid_o;
    input branch_taken_o;
endclocking
```

Това подготвя интерфейса за active driver и passive monitor, без monitor-ът да управлява DUT входове.

---

# 3.4 Transaction/sequence item

Първата реална UVM стъпка е `uvm/qc_sequence_item.sv`. Този клас представя една instruction-level transaction. Той може да се използва както за directed sequences, така и за constrained-random генерация.

Transaction item-ът съдържа:

| Поле | Тип | Роля |
|---|---|---|
| `opcode` | `qc_opcode_e` | Тип операция: `H`, `X`, `CNOT`, `MEASURE`, `WAIT`, `BRANCH` и др. |
| `target_qubit` | `logic [QUBIT_ID_W-1:0]` | Целеви кубит |
| `control_qubit` | `logic [QUBIT_ID_W-1:0]` | Контролен кубит при CNOT |
| `duration` | `logic [DURATION_W-1:0]` | Продължителност или branch target |
| `flags` | `logic [FLAGS_W-1:0]` | Valid, conditional, feedback и expected flags |
| `reserved` | `logic [RESERVED_W-1:0]` | Reserved field |
| `valid_instruction` | `bit` | Управлява valid flag-а при randomизация |
| `allow_invalid_opcode` | `bit` | Позволява генериране на invalid opcode сценарии |
| `raw_override_en` | `bit` | Позволява директно подаване на raw 32-bit инструкция |
| `raw_override_value` | `logic [INSTR_W-1:0]` | Raw override стойност |
| `send_measurement_result` | `bit` | Указва дали sequence/driver да подаде measurement result |
| `measurement_result_value` | `bit` | Стойност на measurement feedback входа |
| `measurement_latency_cycles` | `int unsigned` | Закъснение преди подаване на measurement result |
| `raw_instr` | `logic [INSTR_W-1:0]` | Пакетирана 32-битова инструкция |

## Кодов фрагмент 3.5 – Основни полета на transaction item-а

От `uvm/qc_sequence_item.sv`:

```systemverilog
class qc_sequence_item extends uvm_sequence_item;

    rand qc_opcode_e            opcode;
    rand logic [QUBIT_ID_W-1:0] target_qubit;
    rand logic [QUBIT_ID_W-1:0] control_qubit;
    rand logic [DURATION_W-1:0] duration;
    rand logic [FLAGS_W-1:0]    flags;
    rand logic [RESERVED_W-1:0] reserved;

    rand bit                    valid_instruction;
    rand bit                    allow_invalid_opcode;
    rand bit                    raw_override_en;
    rand logic [INSTR_W-1:0]    raw_override_value;

    rand bit                    send_measurement_result;
    rand bit                    measurement_result_value;
    rand int unsigned           measurement_latency_cycles;

    logic [INSTR_W-1:0]         raw_instr;
```

Тези полета следват формата от `rtl/qc_pkg.sv`, където 32-битовата инструкция е дефинирана като:

```text
[31:28] opcode
[27:24] target_qubit
[23:20] control_qubit
[19:8]  duration
[7:4]   flags
[3:0]   reserved
```

## Кодов фрагмент 3.6 – Constraints за валидни инструкции

Transaction item-ът има constraints, които по подразбиране генерират валидни инструкции и избягват invalid opcode стойности, освен ако тестът изрично не поиска такъв сценарий.

```systemverilog
constraint opcode_c {
    (raw_override_en == 1'b0 && allow_invalid_opcode == 1'b0) ->
        opcode inside {
            OP_NOP,
            OP_H,
            OP_X,
            OP_Z,
            OP_CNOT,
            OP_MEASURE,
            OP_WAIT,
            OP_RESET,
            OP_BRANCH
        };
}

constraint flags_c {
    (raw_override_en == 1'b0) ->
        flags[FLAG_VALID_BIT] == valid_instruction;
}

constraint cnot_qubits_c {
    (raw_override_en == 1'b0 && opcode == OP_CNOT) ->
        target_qubit != control_qubit;
}

constraint wait_duration_c {
    (raw_override_en == 1'b0 && opcode == OP_WAIT) ->
        duration > 0;
}
```

Това е важно за constrained-random тестовете, защото нормалната random генерация не трябва постоянно да създава невалидни инструкции. Invalid сценарии все пак са възможни чрез `allow_invalid_opcode` или чрез `raw_override_en`.

## Кодов фрагмент 3.7 – Пакетиране към реалната 32-битова инструкция

Класът съдържа функция `pack_raw()`, която превръща transaction полетата в реалната 32-битова инструкция, подавана към DUT.

```systemverilog
function logic [INSTR_W-1:0] pack_raw();
    if (raw_override_en) begin
        return raw_override_value;
    end

    return {
        opcode,
        target_qubit,
        control_qubit,
        duration,
        flags,
        reserved
    };
endfunction

function void post_randomize();
    update_raw();
endfunction
```

Това осигурява пряка връзка между UVM transaction слоя и RTL decoder-а. Driver-ът в следваща стъпка трябва да използва `item.pack_raw()` или `item.raw_instr`, за да подаде `instr_i` към DUT.

## Кодов фрагмент 3.8 – Поддръжка на raw directed инструкции

За тестове на illegal opcode, malformed instruction или конкретни regression случаи е добавена функция `load_raw()`.

```systemverilog
function void load_raw(input logic [INSTR_W-1:0] raw);
    qc_instr_t decoded;

    decoded.raw = raw;

    opcode              = decoded.fields.opcode;
    target_qubit        = decoded.fields.target_qubit;
    control_qubit       = decoded.fields.control_qubit;
    duration            = decoded.fields.duration;
    flags               = decoded.fields.flags;
    reserved            = decoded.fields.reserved;
    valid_instruction   = decoded.fields.flags[FLAG_VALID_BIT];
    raw_override_en     = 1'b1;
    raw_override_value  = raw;
    raw_instr           = raw;
endfunction
```

Тази функция е полезна за directed tests, при които трябва да се подаде точно определена 32-битова дума, например същите инструкции, които вече се използват в Verilator testbench-ите.

## Кодов фрагмент 3.9 – Measurement response metadata

Понеже DUT има отделен measurement feedback вход, transaction item-ът съдържа metadata за measurement result подаване.

```systemverilog
rand bit          send_measurement_result;
rand bit          measurement_result_value;
rand int unsigned measurement_latency_cycles;

constraint measurement_response_c {
    (opcode != OP_MEASURE) -> (send_measurement_result == 1'b0);
    (send_measurement_result == 1'b1) -> (opcode == OP_MEASURE);
    measurement_latency_cycles inside {[1:64]};
}
```

Тази metadata вече се използва от `uvm/qc_driver.sv`. Driver-ът изчаква `measure_request_valid_o` и след `measurement_latency_cycles` подава `measurement_result_valid_i` и `measurement_result_i` към DUT.

---

# 3.5 UVM компоненти за stimulus generation, driving, observation и checking

Този раздел описва реализираните stimulus generation, driver, monitor и scoreboard компоненти, както и следващите планирани UVM блокове. Към момента sequencer-ът, sequence класовете, virtual interface-ът, driver-ът, monitor-ът и scoreboard-ът са реализирани, но coverage, agent, environment и executable UVM tests все още предстоят.

## 3.5.1 Sequencer

Реализиран файл:

```text
uvm/qc_sequencer.sv
```

Sequencer-ът е типизиран върху `qc_sequence_item` и предоставя transaction stream към driver-а. Неговата роля е стандартна за UVM active agent: да приема directed или constrained-random sequences и да ги подава към driver-а чрез `seq_item_port`.

## Кодов фрагмент 3.10 – Типизиран UVM sequencer

От `uvm/qc_sequencer.sv`:

```systemverilog
class qc_sequencer extends uvm_sequencer #(qc_sequence_item);

    `uvm_component_utils(qc_sequencer)

    function new(string name = "qc_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : qc_sequencer
```

## 3.5.2 Sequences

Реализиран файл:

```text
uvm/qc_sequences.sv
```

Файлът `uvm/qc_sequences.sv` съдържа базов sequence клас и набор от начални directed, constrained-random, stress и algorithmic sequences. Тези класове генерират `qc_sequence_item` обекти, но още не са изпълнявани срещу DUT, защото UVM agent, environment и testbench top още не са реализирани.

| Sequence class | Статус | Цел |
|---|---|---|
| `qc_base_sequence` | Реализиран | Общ helper слой за flags, raw и structured instruction изпращане |
| `qc_smoke_sequence` | Реализиран | Минимален H → MEASURE → BRANCH сценарий |
| `qc_single_gate_sequence` | Реализиран | Directed H, X и Z инструкции |
| `qc_cnot_sequence` | Реализиран | H + CNOT двукубитен сценарий |
| `qc_measure_sequence` | Реализиран | MEASURE с measurement response metadata |
| `qc_wait_sequence` | Реализиран | WAIT hold/stall stimulus |
| `qc_branch_sequence` | Реализиран | MEASURE + conditional BRANCH + следваща инструкция |
| `qc_invalid_opcode_sequence` | Реализиран | Raw invalid opcode injection |
| `qc_random_instruction_sequence` | Реализиран | Constrained-random валиден instruction stream |
| `qc_dependency_stress_sequence` | Реализиран | Последователни операции върху общи qubit ресурси |
| `qc_algorithmic_bell_sequence` | Реализиран | Bell workload |
| `qc_algorithmic_ghz_sequence` | Реализиран | GHZ workload |
| `qc_algorithmic_grover_like_sequence` | Реализиран | Grover-like workload |

## Кодов фрагмент 3.11 – Helper функция за flags

Базовият sequence клас съдържа функция `make_flags()`, която кодира valid, conditional, feedback и expected битовете със същите bit позиции като RTL package-а.

```systemverilog
function automatic logic [FLAGS_W-1:0] make_flags(
    input bit valid       = 1'b1,
    input bit conditional = 1'b0,
    input bit feedback    = 1'b0,
    input bit expected    = 1'b0
);
    logic [FLAGS_W-1:0] flags;

    flags = '0;
    flags[FLAG_VALID_BIT]       = valid;
    flags[FLAG_CONDITIONAL_BIT] = conditional;
    flags[FLAG_FEEDBACK_BIT]    = feedback;
    flags[FLAG_EXPECTED_BIT]    = expected;

    return flags;
endfunction
```

Така UVM stimulus-ът не използва магически стойности за branch флаговете, а се опира на същите константи, които управляват `instruction_decoder.sv` и `feedback_unit.sv`.

## Кодов фрагмент 3.12 – Structured instruction stimulus

Функцията `send_instruction()` създава `qc_sequence_item`, попълва полетата му и обновява `raw_instr`. Реализираният driver получава точно тези item-и през sequencer-а.

```systemverilog
virtual task send_instruction(
    input qc_opcode_e opcode_i,
    input logic [QUBIT_ID_W-1:0] target_qubit_i  = '0,
    input logic [QUBIT_ID_W-1:0] control_qubit_i = '0,
    input logic [DURATION_W-1:0] duration_i      = 12'd1,
    input logic [FLAGS_W-1:0] flags_i            = (1'b1 << FLAG_VALID_BIT),
    input logic [RESERVED_W-1:0] reserved_i      = '0,
    input bit send_measurement_result_i          = 1'b0,
    input bit measurement_result_value_i         = 1'b0,
    input int unsigned measurement_latency_i     = 3
);
    qc_sequence_item item;

    item = qc_sequence_item::type_id::create("item");

    item.opcode                     = opcode_i;
    item.target_qubit               = target_qubit_i;
    item.control_qubit              = control_qubit_i;
    item.duration                   = duration_i;
    item.flags                      = flags_i;
    item.reserved                   = reserved_i;
    item.valid_instruction          = flags_i[FLAG_VALID_BIT];
    item.allow_invalid_opcode       = 1'b0;
    item.raw_override_en            = 1'b0;
    item.raw_override_value         = '0;
    item.send_measurement_result    = send_measurement_result_i;
    item.measurement_result_value   = measurement_result_value_i;
    item.measurement_latency_cycles = measurement_latency_i;
    item.update_raw();

    start_item(item);
    finish_item(item);
endtask
```

## Кодов фрагмент 3.13 – Smoke sequence

`qc_smoke_sequence` е минимален end-to-end stimulus шаблон: gate операция, measurement операция и conditional feedback branch.

```systemverilog
virtual task body();
    send_instruction(OP_H,       4'd0, 4'd0, 12'd4,  make_flags());
    send_instruction(OP_MEASURE, 4'd0, 4'd0, 12'd6,  make_flags(), '0, 1'b1, 1'b1, 3);
    send_instruction(OP_BRANCH,  4'd0, 4'd0, 12'd16, make_flags(1'b1, 1'b1, 1'b1, 1'b1));
endtask
```

Този sequence е полезен за първия бъдещ UVM smoke test, защото преминава през gate path, measurement path и feedback path.

## Кодов фрагмент 3.14 – Constrained-random instruction stream

`qc_random_instruction_sequence` използва constraints от `qc_sequence_item`, за да генерира валидни инструкции без raw override и без invalid opcode injection.

```systemverilog
repeat (item_count) begin
    item = qc_sequence_item::type_id::create("random_item");

    start_item(item);
    if (!item.randomize() with {
        raw_override_en == 1'b0;
        allow_invalid_opcode == 1'b0;
        valid_instruction == 1'b1;
    }) begin
        `uvm_error(get_type_name(), "Failed to randomize qc_sequence_item")
    end
    finish_item(item);
end
```

Този sequence е основата за бъдещи random regression тестове. След добавяне на coverage, agent/env и executable UVM tests той ще може да проверява по-дълги валидни instruction streams.

## Кодов фрагмент 3.15 – Algorithmic Bell workload

`qc_algorithmic_bell_sequence` показва как алгоритмично мотивиран workload се представя чрез същия instruction-level API.

```systemverilog
virtual task body();
    send_instruction(OP_H,       4'd0, 4'd0, 12'd4, make_flags());
    send_instruction(OP_CNOT,    4'd1, 4'd0, 12'd8, make_flags());
    send_instruction(OP_MEASURE, 4'd0, 4'd0, 12'd6, make_flags(), '0, 1'b1, 1'b0, 3);
    send_instruction(OP_MEASURE, 4'd1, 4'd0, 12'd6, make_flags(), '0, 1'b1, 1'b0, 3);
endtask
```

Тук Bell workload-ът не е физическа квантова симулация, а instruction-level stimulus за контролера. Той проверява дали контролерът може да обработи последователност от еднокубитна операция, двукубитна операция и измервания.

## 3.5.3 Driver

Реализиран файл:

```text
uvm/qc_driver.sv
```

Driver-ът вече:

1. Извлича `qc_sequence_item` от sequencer-а.
2. Изчаква `instr_ready_o`.
3. Подава `instr_i = item.pack_raw()`.
4. Активира `instr_valid_i` според ready/valid протокола.
5. При measurement transaction изчаква `measure_request_valid_o`, след което подава `measurement_result_valid_i` и `measurement_result_i` след `measurement_latency_cycles`.

Driver-ът получава virtual interface чрез `uvm_config_db`. Това означава, че бъдещите `qc_agent`, `qc_env` и `tb_qc_uvm_top` трябва да зададат `vif` към `qc_driver` преди стартиране на теста.

## Кодов фрагмент 3.16 – Driver build/run phase

От `uvm/qc_driver.sv`:

```systemverilog
class qc_driver extends uvm_driver #(qc_sequence_item);

    virtual qc_if vif;

    `uvm_component_utils(qc_driver)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual qc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface 'vif' was not provided")
        end
    endfunction

    task run_phase(uvm_phase phase);
        qc_sequence_item item;

        initialize_bus();
        wait_for_reset_release();

        forever begin
            seq_item_port.get_next_item(item);
            drive_item(item);
            seq_item_port.item_done();
        end
    endtask
```

Този код превръща sequence item stream-а в реално driver поведение, но все още изисква agent/env/top слой, за да бъде изпълнен срещу DUT.

## Кодов фрагмент 3.17 – Ready/valid instruction drive

Driver-ът пакетира instruction transaction-а и го държи валиден, докато DUT вдигне `instr_ready_o`.

```systemverilog
task drive_instruction(qc_sequence_item item);
    logic [INSTR_W-1:0] raw_instr;

    raw_instr = item.pack_raw();

    vif.drv_cb.instr_i       <= raw_instr;
    vif.drv_cb.instr_valid_i <= 1'b1;

    do begin
        @(vif.drv_cb);
    end while (vif.drv_cb.instr_ready_o !== 1'b1);

    vif.drv_cb.instr_valid_i <= 1'b0;
    vif.drv_cb.instr_i       <= '0;
endtask
```

Това е първата реална връзка между sequence item модела и входния DUT интерфейс.

## Кодов фрагмент 3.18 – Measurement response handling

За measurement sequence item-и driver-ът изчаква measurement request и подава резултат след зададен latency.

```systemverilog
task drive_measurement_response(qc_sequence_item item);
    bit request_seen;

    wait_for_measurement_request(item, request_seen);

    if (!request_seen) begin
        return;
    end

    repeat (item.measurement_latency_cycles) begin
        @(vif.drv_cb);
    end

    vif.drv_cb.measurement_result_i       <= item.measurement_result_value;
    vif.drv_cb.measurement_result_valid_i <= 1'b1;

    @(vif.drv_cb);

    vif.drv_cb.measurement_result_valid_i <= 1'b0;
    vif.drv_cb.measurement_result_i       <= 1'b0;
endtask
```

Тази логика използва `send_measurement_result`, `measurement_result_value` и `measurement_latency_cycles` от `qc_sequence_item`.

## 3.5.4 Monitor

Реализирани файлове:

```text
uvm/qc_observation_item.sv
uvm/qc_monitor.sv
```

Monitor-ът е пасивен UVM компонент. Той не управлява DUT входове, а използва `virtual qc_if` и `mon_cb`, за да наблюдава вече описаните DUT сигнали. За да не се обвързват бъдещите scoreboard и coverage компоненти директно със signal-level интерфейса, monitor-ът публикува нормализирани observation transactions от тип `qc_observation_item`.

`qc_observation_item` съдържа отделни полета за:

| Група | Полета |
|---|---|
| Instruction/decode | `raw_instr`, `opcode`, `target_qubit`, `control_qubit`, `duration`, `flags`, `reserved` |
| Command classification | `gate_cmd`, `measure_cmd`, `wait_cmd`, `reset_cmd`, `branch_cmd`, `nop_cmd` |
| Measurement request | `measure_request_valid`, `measure_qubit`, `measurement_busy` |
| Measurement response input | `measurement_response_valid`, `measurement_response_value` |
| Measurement result output | `measurement_result_valid`, `measurement_result_qubit`, `measurement_result_value`, `measurement_valid`, `measurement_results` |
| Feedback/branch | `feedback_valid`, `branch_taken`, `branch_target`, `feedback_qubit`, `feedback_value`, `condition_checked`, `missing_measurement` |
| Status/debug | `scheduler_stall`, `illegal_instr`, `illegal_issue`, `unexpected_measurement_result`, `queue_count`, `qubit_busy` |

Monitor-ът създава следните observation типове:

| Observation kind | Кога се публикува | За какво ще се използва |
|---|---|---|
| `QC_OBS_INSTRUCTION` | При `instr_valid_i && instr_ready_o` | Проверка на приети инструкции и входен ред |
| `QC_OBS_ISSUE` | При `issue_valid_o` | Сравнение между decoder/queue/scheduler issue поведение |
| `QC_OBS_COMMAND` | При command/classification активност | Проверка на execution controller command path |
| `QC_OBS_MEASURE_REQUEST` | При `measure_request_valid_o` | Проверка на measurement request path |
| `QC_OBS_MEASURE_RESPONSE` | При `measurement_result_valid_i` | Корелация между driver response и DUT output |
| `QC_OBS_MEASURE_RESULT` | При `measurement_result_out_valid_o` | Проверка на съхранен measurement резултат |
| `QC_OBS_FEEDBACK` | При feedback/branch/missing measurement активност | Проверка на feedback/branch unit |
| `QC_OBS_STATUS` | При status флагове или промяна на `queue_count_o`/`qubit_busy_o` | Scoreboard и coverage за stall, illegal и queue/busy състояния |

## Кодов фрагмент 3.19 – Observation item типове

От `uvm/qc_observation_item.sv`:

```systemverilog
typedef enum int unsigned {
    QC_OBS_INSTRUCTION,
    QC_OBS_ISSUE,
    QC_OBS_COMMAND,
    QC_OBS_MEASURE_REQUEST,
    QC_OBS_MEASURE_RESPONSE,
    QC_OBS_MEASURE_RESULT,
    QC_OBS_FEEDBACK,
    QC_OBS_STATUS
} qc_observation_kind_e;

class qc_observation_item extends uvm_sequence_item;

    qc_observation_kind_e       kind;
    logic [INSTR_W-1:0]         raw_instr;
    qc_opcode_e                 opcode;
    logic [QUBIT_ID_W-1:0]      target_qubit;
    logic [QUBIT_ID_W-1:0]      control_qubit;
    logic [DURATION_W-1:0]      duration;
    logic [FLAGS_W-1:0]         flags;
```

Този клас е отделен от `qc_sequence_item`, защото stimulus transaction-ът и observed transaction-ът имат различна роля. `qc_sequence_item` описва какво иска тестът да подаде към DUT, докато `qc_observation_item` описва какво реално е наблюдавано по входните, вътрешно-архитектурните и изходните DUT интерфейси.

## Кодов фрагмент 3.20 – Analysis port и virtual interface в monitor-а

От `uvm/qc_monitor.sv`:

```systemverilog
class qc_monitor extends uvm_monitor;

    virtual qc_if vif;

    uvm_analysis_port #(qc_observation_item) analysis_port;

    `uvm_component_utils(qc_monitor)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual qc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface 'vif' was not provided")
        end
    endfunction
```

Това е същият `vif` pattern като при driver-а. Бъдещият `qc_agent` трябва да зададе един и същ virtual interface към driver-а и monitor-а, а monitor-ът ще подава наблюденията към scoreboard и coverage чрез `analysis_port`.

## Кодов фрагмент 3.21 – Основен monitor sampling loop

Monitor-ът изчаква reset release и след това взема проба на всеки clocking block цикъл. В рамките на един цикъл може да публикува повече от един observation item, например accepted instruction, command и status.

```systemverilog
task run_phase(uvm_phase phase);
    wait_for_reset_release();

    forever begin
        @(vif.mon_cb);

        if (vif.mon_cb.rst_ni !== 1'b1) begin
            have_status_sample = 1'b0;
            continue;
        end

        sample_cycle();
    end
endtask

function void sample_cycle();
    if (vif.mon_cb.instr_valid_i && vif.mon_cb.instr_ready_o) begin
        sample_instruction();
    end

    if (vif.mon_cb.issue_valid_o) begin
        sample_issue();
    end

    if (vif.mon_cb.command_valid_o ||
        vif.mon_cb.gate_cmd_o ||
        vif.mon_cb.measure_cmd_o ||
        vif.mon_cb.wait_cmd_o ||
        vif.mon_cb.reset_cmd_o ||
        vif.mon_cb.branch_cmd_o ||
        vif.mon_cb.nop_cmd_o) begin
        sample_command();
    end
endfunction
```

Instruction observation-ът се публикува само при реален ready/valid handshake, тоест когато DUT действително е приел инструкцията. Това е важно за scoreboard-а, защото входната опашка и backpressure сценарии не трябва да броят неприети инструкции като изпълнени.

## Кодов фрагмент 3.22 – Measurement, feedback и status observation

Monitor-ът наблюдава както measurement request към външен измервателен блок, така и measurement response входа, който driver-ът подава към DUT. Това позволява scoreboard-ът да провери дали подаденият резултат се появява като коректен `measurement_result_out_valid_o` и дали feedback unit-ът използва правилната стойност, след като monitor и scoreboard бъдат свързани в agent/env слоя.

```systemverilog
if (vif.mon_cb.measure_request_valid_o) begin
    sample_measure_request();
end

if (vif.mon_cb.measurement_result_valid_i) begin
    sample_measure_response();
end

if (vif.mon_cb.measurement_result_out_valid_o) begin
    sample_measure_result();
end

if (vif.mon_cb.feedback_valid_o ||
    vif.mon_cb.branch_taken_o ||
    vif.mon_cb.condition_checked_o ||
    vif.mon_cb.missing_measurement_o) begin
    sample_feedback();
end

if (should_sample_status()) begin
    sample_status();
end
```

Status observation-ът не се публикува само при error флагове. Той се публикува и при промяна на `queue_count_o` или `qubit_busy_o`, защото тези сигнали са нужни за бъдещата проверка на queue/backpressure и dependency/stall поведение.

## Как се проверява C4

На този етап monitor-ът е code-complete като UVM компонент, но не е изпълняван в реална UVM симулация. Причината е същото toolchain ограничение: липсват UVM agent/env/top и UVM-capable simulator flow. Минималната текуща проверка е:

```text
1. `uvm/qc_uvm_pkg.sv` include-ва `qc_observation_item.sv` преди `qc_monitor.sv`.
2. `qc_monitor.sv` използва същия `virtual qc_if` pattern като driver-а.
3. Monitor-ът публикува само през `uvm_analysis_port #(qc_observation_item)`.
4. Няма claim за PASS UVM simulation, докато не се добавят agent/env/top и реален simulator run.
```

Следващата практическа проверка трябва да стане при добавяне на `qc_agent.sv` и `qc_env.sv`, където `monitor.analysis_port` ще бъде свързан към scoreboard и coverage subscribers.

## 3.5.5 Scoreboard

Реализиран файл:

```text
uvm/qc_scoreboard.sv
```

Scoreboard-ът реализира първи reference модел върху observation stream-а от monitor-а. Той не чете директно `qc_if`, а приема `qc_observation_item` чрез UVM analysis implementation. Това запазва архитектурното разделение:

```text
qc_monitor
→ qc_observation_item stream
→ qc_scoreboard
```

Реализираният scoreboard проверява следните групи поведение:

| Проверка | Очакване |
|---|---|
| Valid decode | Валидна инструкция не трябва да активира `illegal_instr_o` |
| Invalid opcode | Невалидна инструкция трябва да активира illegal path |
| Gate command | H/X/Z/CNOT трябва да водят до `gate_cmd_o` |
| Measure command | MEASURE трябва да води до `measure_cmd_o` и `measure_request_valid_o` |
| WAIT | WAIT трябва да предизвика временно задържане на scheduler-а |
| RESET | RESET трябва да активира reset command classification |
| Branch unconditional | Unconditional branch трябва да води до `branch_taken_o` |
| Branch conditional taken | Measurement result == expected bit трябва да вземе branch |
| Branch conditional not taken | Measurement result != expected bit не трябва да вземе branch |
| Missing measurement | Conditional branch без measurement трябва да активира `missing_measurement_o` |
| Queue/backpressure | Queue count и stall поведение трябва да останат консистентни |

Scoreboard-ът е консервативен: той проверява причинно-следствени отношения между наблюдавани събития, но не твърди пълна cycle-accurate симулация на scheduler-а. Това е правилно за текущия етап, защото agent/env/top още липсват и UVM средата все още не е пускана в реален simulator.

## Кодов фрагмент 3.23 – Scoreboard analysis вход

От `uvm/qc_scoreboard.sv`:

```systemverilog
class qc_scoreboard extends uvm_component;

    uvm_analysis_imp #(qc_observation_item, qc_scoreboard) analysis_export;

    `uvm_component_utils(qc_scoreboard)

    function new(string name = "qc_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        reset_model();
    endfunction

    function void write(qc_observation_item obs);
        case (obs.kind)
            QC_OBS_INSTRUCTION:      handle_instruction(obs);
            QC_OBS_ISSUE:            handle_issue(obs);
            QC_OBS_COMMAND:          handle_command(obs);
            QC_OBS_MEASURE_REQUEST:  handle_measure_request(obs);
            QC_OBS_MEASURE_RESPONSE: handle_measure_response(obs);
            QC_OBS_MEASURE_RESULT:   handle_measure_result(obs);
            QC_OBS_FEEDBACK:         handle_feedback(obs);
            QC_OBS_STATUS:           handle_status(obs);
        endcase
    endfunction
```

Това е централната входна точка на checking слоя. Всеки observation kind от monitor-а се насочва към отделна handler функция. Така финалният текст може ясно да раздели проверките за instruction flow, command classification, measurement flow, feedback/branch и status/error сигнали.

## Кодов фрагмент 3.24 – Очаквани опашки за instruction → issue → command

Scoreboard-ът пази очакваните инструкции в няколко FIFO структури. Accepted instruction observation-ите се превръщат в очаквани issue събития, issue събитията се превръщат в очаквани command събития.

```systemverilog
typedef struct {
    qc_opcode_e             opcode;
    logic [QUBIT_ID_W-1:0]  target_qubit;
    logic [QUBIT_ID_W-1:0]  control_qubit;
    logic [DURATION_W-1:0]  duration;
    logic [FLAGS_W-1:0]     flags;
    logic [INSTR_W-1:0]     raw_instr;
    time                    sample_time;
} expected_instr_t;

expected_instr_t expected_issue_q[$];
expected_instr_t expected_command_q[$];

function void handle_instruction(qc_observation_item obs);
    expected_instr_t expected;

    instruction_count++;

    if (!is_legal_opcode(obs.opcode)) begin
        pending_illegal_instr_count++;
        return;
    end

    if (!obs.flags[FLAG_VALID_BIT]) begin
        return;
    end

    expected = expected_from_obs(obs);
    expected_issue_q.push_back(expected);
endfunction
```

Тази логика отразява поведението на `rtl/quantum_controller_top.sv`: инструкцията влиза в queue само ако е приета през ready/valid handshake, има valid flag и не е illegal opcode. Невалидните opcode-и не се очакват на issue stage, а се очаква по-късно `illegal_instr_o` status observation.

## Кодов фрагмент 3.25 – Проверка на command classification

За всяка issued инструкция scoreboard-ът очаква command observation и проверява дали command class битът съответства на opcode-а. Това е пряка проверка на `rtl/execution_controller.sv`.

```systemverilog
function void check_command_classification(
    expected_instr_t expected,
    qc_observation_item obs
);
    if (command_class_count(obs) != 1) begin
        `uvm_error(get_type_name(),
                   $sformatf("Command classification is not one-hot for opcode %s: %s",
                             expected.opcode.name(),
                             obs.convert2string()))
    end

    case (expected.opcode)
        OP_NOP: begin
            check_command_bit("nop_cmd", obs.nop_cmd, 1'b1, expected);
        end

        OP_H,
        OP_X,
        OP_Z,
        OP_CNOT: begin
            check_command_bit("gate_cmd", obs.gate_cmd, 1'b1, expected);
        end

        OP_MEASURE: begin
            check_command_bit("measure_cmd", obs.measure_cmd, 1'b1, expected);
        end

        OP_WAIT: begin
            check_command_bit("wait_cmd", obs.wait_cmd, 1'b1, expected);
        end

        OP_RESET: begin
            check_command_bit("reset_cmd", obs.reset_cmd, 1'b1, expected);
        end

        OP_BRANCH: begin
            check_command_bit("branch_cmd", obs.branch_cmd, 1'b1, expected);
        end
    endcase
endfunction
```

Тук има и one-hot проверка. Тя е важна, защото `execution_controller.sv` трябва да активира точно една command категория за всяка issued операция. При `OP_NOP` top-level command fields са нулирани, но `nop_cmd_o` остава видим classification сигнал, затова scoreboard-ът проверява NOP отделно.

## Кодов фрагмент 3.26 – Measurement request/response/result корелация

Measurement проверката следва реалното поведение на `rtl/measurement_controller.sv`: MEASURE command води до request, driver response води до result output, а резултатът се записва в measurement state model-а.

```systemverilog
expected_measurement_t expected_measure_request_q[$];
expected_measurement_t outstanding_measurement_q[$];
expected_measurement_t expected_measure_result_q[$];

function void handle_measure_request(qc_observation_item obs);
    expected_measurement_t expected;

    measure_request_count++;
    expected = expected_measure_request_q.pop_front();

    if (obs.measure_qubit !== expected.qubit) begin
        `uvm_error(get_type_name(),
                   $sformatf("Measurement request qubit mismatch: expected q%0d observed q%0d",
                             expected.qubit,
                             obs.measure_qubit))
    end

    outstanding_measurement_q.push_back(expected);
endfunction

function void handle_measure_response(qc_observation_item obs);
    expected_measurement_t expected;

    measure_response_count++;
    expected       = outstanding_measurement_q.pop_front();
    expected.value = obs.measurement_response_value;

    expected_measure_result_q.push_back(expected);
endfunction

function void handle_measure_result(qc_observation_item obs);
    expected_measurement_t expected;

    measure_result_count++;
    expected = expected_measure_result_q.pop_front();

    measurement_valid_model[expected.qubit]   = 1'b1;
    measurement_results_model[expected.qubit] = expected.value;
endfunction
```

Реалният файл съдържа и defensive checks за празни опашки, mismatch на qubit/value, `measurement_valid_o[qubit]` и `measurement_results_o[qubit]`. Този модел е нужен за следващата проверка: conditional feedback branch.

## Кодов фрагмент 3.27 – Feedback/branch reference модел

Feedback проверката моделира поведението на `rtl/feedback_unit.sv`: unconditional branch винаги се взема, conditional/feedback branch се взема само ако има валиден measurement резултат и той съвпада с expected bit-а.

```systemverilog
function void handle_feedback(qc_observation_item obs);
    expected_instr_t expected;
    bit              expected_conditional;
    bit              expected_selected_valid;
    bit              expected_selected_value;
    bit              expected_branch_taken;

    feedback_count++;

    expected = expected_feedback_q.pop_front();
    expected_conditional = is_conditional_branch(expected);
    expected_selected_valid = measurement_valid_model[expected.target_qubit];
    expected_selected_value = measurement_results_model[expected.target_qubit];

    if (expected_conditional) begin
        if (expected_selected_valid) begin
            expected_branch_taken = (expected_selected_value ==
                                     expected.flags[FLAG_EXPECTED_BIT]);
        end else begin
            expected_branch_taken = 1'b0;
        end
    end else begin
        expected_branch_taken = 1'b1;
    end

    if (obs.branch_taken !== expected_branch_taken) begin
        `uvm_error(get_type_name(),
                   $sformatf("Branch decision mismatch: expected %0b observed %0b",
                             expected_branch_taken,
                             obs.branch_taken))
    end

    if (expected_branch_taken) begin
        expected_issue_q.delete();
    end
endfunction
```

При taken branch scoreboard-ът изчиства очакваната issue опашка, защото `operation_queue` трябва да flush-не по-младите инструкции. Това е важна връзка между verification model-а и control-flow корекциите, описани в Глава 2.

## Кодов фрагмент 3.28 – Status checks и summary

Scoreboard-ът обработва status observation-и за illegal instruction, unexpected measurement result, illegal issue, queue count и unknown busy state.

```systemverilog
function void handle_status(qc_observation_item obs);
    status_count++;

    if (obs.illegal_instr) begin
        if (pending_illegal_instr_count == 0) begin
            `uvm_error(get_type_name(),
                       $sformatf("Unexpected illegal_instr observation: %s",
                                 obs.convert2string()))
        end else begin
            pending_illegal_instr_count--;
        end
    end

    if (obs.illegal_issue) begin
        `uvm_error(get_type_name(),
                   $sformatf("illegal_issue_o should not occur for decoded legal instructions: %s",
                             obs.convert2string()))
    end

    if (obs.queue_count > max_queue_depth) begin
        `uvm_error(get_type_name(),
                   $sformatf("Queue count exceeded configured depth: count=%0d depth=%0d",
                             obs.queue_count,
                             max_queue_depth))
    end
endfunction
```

В `check_phase()` scoreboard-ът не маркира автоматично non-empty expected queues като грешка, а ги отчита като warnings. Причината е, че executable UVM tests и phase objections още не са реализирани; след добавяне на `qc_base_test.sv` и test top тези warnings могат да бъдат затегнати към errors за тестове, които трябва да drain-нат pipeline-а.

## Как се проверява C5

На този етап `qc_scoreboard.sv` е реализиран като UVM checking компонент, но още не е свързан в реална среда. Минималната текуща проверка е:

```text
1. `uvm/qc_uvm_pkg.sv` include-ва `qc_scoreboard.sv` след `qc_monitor.sv`.
2. Scoreboard-ът приема `qc_observation_item` през `uvm_analysis_imp`.
3. Има отделни handlers за всички observation kind стойности от monitor-а.
4. Reference моделът покрива instruction/issue/command, measurement и feedback/status проверки.
5. Няма claim за PASS UVM simulation, докато не се добавят agent/env/top и реален simulator run.
```

Следващата практическа стъпка е `uvm/qc_coverage.sv`, а след това `qc_agent.sv` и `qc_env.sv`, където `monitor.analysis_port` ще се свърже към `scoreboard.analysis_export` и coverage subscriber-а.

## 3.5.6 Coverage

Планиран файл:

```text
uvm/qc_coverage.sv
```

Coverage моделът трябва да измерва не само opcode покритие, а и важни cross сценарии:

| Coverage категория | Примерни bins/cross |
|---|---|
| Opcode coverage | NOP, H, X, Z, CNOT, MEASURE, WAIT, RESET, BRANCH, INVALID |
| Qubit coverage | target qubit и control qubit разпределение |
| Flag coverage | valid, conditional, feedback, expected |
| Opcode × flags | BRANCH × conditional/feedback/expected |
| Measurement coverage | measurement request, result value 0/1, busy behavior |
| Branch coverage | taken, not taken, missing measurement |
| Scheduler coverage | stall, no-stall, dependency hazard, WAIT hold |
| Queue coverage | empty, non-empty, full, flush |
| Algorithmic coverage | Bell, GHZ, Grover-like, random-circuit-inspired workloads |

Coverage collector-ът също трябва да бъде subscriber към `qc_observation_item` потока, за да покрива реално наблюдавани DUT събития, а не само генериран stimulus.

---

# 3.6 Test plan

## 3.6.1 Directed tests

Все още няма executable UVM directed tests, защото липсват UVM environment, test top и run script. Вече има реализирани directed sequence класове в `uvm/qc_sequences.sv` и driver в `uvm/qc_driver.sv`, които ще бъдат използвани от бъдещите UVM tests.

Като functional baseline съществуват Verilator testbench-и в `tb/`, включително:

```text
tb/tb_qc_pkg.sv
tb/tb_instruction_decoder.sv
tb/tb_operation_queue.sv
tb/tb_dependency_tracker.sv
tb/tb_scheduler.sv
tb/tb_execution_controller.sv
tb/tb_measurement_controller.sv
tb/tb_feedback_unit.sv
tb/tb_quantum_controller_top.sv
```

Те не са UVM tests и не трябва да се описват като такива. Тяхната роля за Глава 3 е да служат като източник на directed сценарии, които трябва да бъдат прехвърлени в UVM sequences.

Текущите directed sequence класове покриват следните сценарии:

| Sequence | Покрит сценарий |
|---|---|
| `qc_smoke_sequence` | H → MEASURE → conditional BRANCH |
| `qc_single_gate_sequence` | H, X и Z |
| `qc_cnot_sequence` | H + CNOT |
| `qc_measure_sequence` | MEASURE с measurement response metadata |
| `qc_wait_sequence` | WAIT между две gate операции |
| `qc_branch_sequence` | MEASURE + conditional branch + по-млада инструкция |
| `qc_invalid_opcode_sequence` | Raw invalid opcode |

След добавяне на agent/env, UVM test класове и top-level testbench тези sequence класове трябва да бъдат обвити в executable UVM tests, например `qc_smoke_test`, `qc_single_gate_test`, `qc_measure_test`, `qc_branch_test` и `qc_invalid_opcode_test`.

## 3.6.2 Constrained-random и stress tests

Все още няма executable UVM constrained-random или stress tests, но вече има sequence класове за random и dependency stress stimulus.

Реализирани sequence класове:

| Sequence | Описание |
|---|---|
| `qc_random_instruction_sequence` | Random opcode, qubit, duration и flag комбинации с валиден instruction format |
| `qc_dependency_stress_sequence` | Операции върху едни и същи qubit ресурси за dependency/stall stimulus |

Остават за бъдещо разширяване:

| Направление | Описание |
|---|---|
| Queue pressure | Дълги instruction bursts за full/non-empty queue състояния |
| Measurement latency variation | Различни latency стойности за measurement result подаване |
| Branch feedback variation | Conditional branch с expected 0/1 и measurement 0/1 |
| Illegal injection | По-богато контролирано вкарване на invalid opcode/raw malformed инструкции |
| Long WAIT stress | WAIT операции с различна продължителност |

## 3.6.3 Algorithmic workloads

Вече има реализирани UVM sequence класове за начални algorithmic workloads, но те все още не са изпълнявани срещу DUT.

Реализираните algorithmic sequence класове са:

| Sequence | Instruction идея | Цел |
|---|---|---|
| `qc_algorithmic_bell_sequence` | H върху q0, CNOT q0→q1, measurement | Проверка на зависимост между еднокубитна и двукубитна операция |
| `qc_algorithmic_ghz_sequence` | H върху q0, CNOT chain, measurements | Проверка на последователни multi-qubit зависимости |
| `qc_algorithmic_grover_like_sequence` | H/X/Z/CNOT/MEASURE/conditional BRANCH pattern | Проверка на смесени gate и feedback сценарии |

Остават за бъдещо добавяне:

| Workload | Цел |
|---|---|
| Measurement-feedback workload variants | Повече комбинации от expected/result branch outcomes |
| Random-circuit-inspired workload | По-дълги random gate streams върху различни qubit-и |

Тези workloads са алгоритмично мотивирани. Те не трябва да се описват като физическа квантова симулация или като възпроизвеждане на реален quantum backend.

---

# 3.7 Стартиране на симулации

Към момента наличният локален simulation flow е Verilator flow за non-UVM testbench-и:

```bash
./scripts/run_verilator.sh all
```

Този flow проверява RTL testbench-ите в `tb/`, но не изпълнява UVM среда.

Проверка на наличните simulator команди към момента показа:

```text
verilator: наличен
vlog/vsim: не са налични в PATH
xrun: не е наличен в PATH
vcs: не е наличен в PATH
```

Тъй като класическа UVM среда обикновено изисква UVM-capable simulator като Questa/ModelSim, VCS или Xcelium, към момента UVM кодът не е изпълнен в симулация. Това трябва да бъде описано като текущо toolchain ограничение, докато не бъде добавен подходящ simulator flow.

Планиран бъдещ script:

```text
scripts/run_uvm.sh
```

Той трябва да компилира поне:

```text
rtl/qc_pkg.sv
uvm/qc_if.sv
uvm/qc_uvm_pkg.sv
rtl/instruction_decoder.sv
rtl/operation_queue.sv
rtl/dependency_tracker.sv
rtl/scheduler.sv
rtl/execution_controller.sv
rtl/measurement_controller.sv
rtl/feedback_unit.sv
rtl/quantum_controller_top.sv
uvm/tb_qc_uvm_top.sv
```

и да стартира избран UVM test чрез `+UVM_TESTNAME=...`.

Файловете `qc_sequence_item.sv`, `qc_observation_item.sv`, `qc_sequencer.sv`, `qc_sequences.sv`, `qc_driver.sv`, `qc_monitor.sv` и `qc_scoreboard.sv` се включват през `uvm/qc_uvm_pkg.sv`, затова run script-ът трябва да подаде правилен include path към директорията `uvm/`.

---

# 3.8 Logs, waveforms и coverage резултати

Към момента няма UVM-generated logs, waveforms или coverage reports, защото UVM testbench още не е реализиран и не е изпълняван с UVM-capable simulator.

Наличните резултати от проекта са от RTL Verilator regression flow:

```text
results/simulation_logs/
results/waveforms/
```

Тези резултати могат да се използват като baseline доказателство, че RTL работи преди започване на UVM, но не трябва да се представят като UVM резултати.

След реализиране на UVM средата тук трябва да се добавят:

| Артефакт | Очаквано съдържание |
|---|---|
| UVM run logs | Pass/fail логове за directed, random и algorithmic tests |
| UVM waveforms | Waveform файлове за key scenarios |
| Coverage reports | Functional coverage summary и missing bins |
| Regression summary | Таблица test → status → seed → log |

Финалната версия на този раздел трябва да съдържа реална regression таблица, а не само описание на планирани тестове. Минималният формат е:

| UVM test | Sequence | Status | Seed | Log | Waveform/Coverage | Какво проверява |
|---|---|---|---:|---|---|---|
| `qc_smoke_test` | `qc_smoke_sequence` | TBD | 1 | `results/uvm_logs/qc_smoke_test.log` | TBD | H → MEASURE → BRANCH |
| `qc_single_gate_test` | `qc_single_gate_sequence` | TBD | 1 | `results/uvm_logs/qc_single_gate_test.log` | TBD | H/X/Z command path |
| `qc_branch_test` | `qc_branch_sequence` | TBD | 1 | `results/uvm_logs/qc_branch_test.log` | TBD | Measurement feedback branch |

В тази таблица `PASS` може да се запише само след реално изпълнена UVM симулация с UVM-capable simulator. До тогава статусът трябва да остане `TBD`, `NOT RUN` или еквивалентно ясно обозначение.

---

# 3.9 Ограничения на текущата UVM среда

Текущите ограничения са:

1. Реализирани са UVM package, transaction/sequence item, observation item, sequencer, начални sequence класове, virtual interface, driver и monitor.
2. Няма coverage collector, agent, env или executable UVM tests.
3. DUT сигналите са описани в `qc_if.sv`, а monitor-ът ги наблюдава през `mon_cb`, но все още няма `tb_qc_uvm_top.sv`, който да инстанцира `quantum_controller_top` и да го свърже към interface-а.
4. Няма UVM simulation script.
5. Няма потвърден UVM simulator в PATH освен Verilator, който се използва за съществуващите non-UVM RTL testbench-и.
6. Няма UVM logs, UVM waveforms или UVM coverage reports.
7. Constrained-random, stress и algorithmic workloads съществуват като sequence класове, но не са изпълнявани и още нямат реални scoreboard/coverage simulation резултати.

Тези ограничения са нормални за текущия етап, защото Phase C току-що е започната. Те трябва да бъдат премахвани постепенно с всяка следваща реализация.

---

# 3.10 Предложена структура за финалната Глава 3

Спрямо текущия работен план структурата на Глава 3 може да остане в следната логика:

```text
3.1 Методология на функционалната верификация
3.2 Архитектура на UVM средата
3.3 Transaction model и sequence item
3.4 Sequencer, sequences и stimulus generation
3.5 Driver, monitor и DUT свързване
3.6 Scoreboard и reference модел
3.7 Functional coverage модел
3.8 Directed, constrained-random, stress и algorithmic tests
3.9 Симулационни резултати, logs, waveforms и coverage
3.10 Ограничения и обобщение
```

Ако при разработката се окаже, че measurement responder или отделен passive monitor са достатъчно важни, може да се добави отделен подраздел за тях. Засега не е нужна радикална промяна в структурата, но е полезно `transaction model`, `DUT свързване`, `scoreboard` и `coverage` да бъдат отделни подраздели, защото това ще направи финалната глава по-проследима.

---

# 3.11 Следващи непосредствени стъпки

Следващата реална стъпка по Phase C е:

```text
C6: qc_coverage.sv
```

Препоръчителен ред:

1. Създаване на `uvm/qc_coverage.sv`.
2. Coverage компонентът трябва да бъде subscriber към `qc_observation_item` потока.
3. Трябва да има covergroups за opcode, command class, flags, measurement request/result, feedback/branch, illegal/status и queue/busy състояния.
4. Трябва да има cross coverage за `BRANCH × conditional/feedback/expected/result`, `MEASURE × result value`, `opcode × command class` и stall/queue scenarios.
5. Обновяване на `uvm/qc_uvm_pkg.sv`, за да include-ва coverage компонента.
6. Обновяване на този Markdown файл с реални code excerpts от coverage модела.
7. Обновяване на `docs/AGENT_CONTEXT.md` с новия UVM статус.

След coverage трябва да се премине към `qc_agent.sv` и `qc_env.sv`, защото тогава driver, monitor, scoreboard и coverage ще могат да бъдат свързани в реална UVM среда.

---

# 3.12 Definition of Done за UVM фазата

Глава 3 може да се счита за готова за финално академично писане само когато UVM средата е не само написана, но и проверена с реални simulation artifacts. Минималните критерии са:

1. Съществува `uvm/qc_if.sv`, който описва DUT сигналите и clocking/reset достъпа за UVM компонентите.
2. Съществува `uvm/qc_driver.sv`, който управлява `instr_i`, `instr_valid_i` и спазва `instr_ready_o`.
3. Driver-ът или отделен response механизъм обработва measurement response metadata от `qc_sequence_item`: `send_measurement_result`, `measurement_result_value` и `measurement_latency_cycles`.
4. Съществува `uvm/qc_monitor.sv`, който наблюдава входния instruction интерфейс, command/issue изходите, measurement сигналите, branch/feedback сигналите и status/debug сигналите.
5. Monitor-ът използва analysis ports, така че наблюдаваните транзакции да могат да се подават към scoreboard и coverage.
6. Съществува `uvm/qc_scoreboard.sv` с reference checks за gate, measure, wait, reset, branch, illegal instruction, measurement feedback и основни queue/backpressure сценарии.
7. Съществува `uvm/qc_coverage.sv` с functional coverage за opcode, flags, branch outcomes, measurement behavior, scheduler stall, queue state и algorithmic workloads.
8. Съществуват `uvm/qc_agent.sv` и `uvm/qc_env.sv`, които свързват sequencer, driver, monitor, scoreboard и coverage в цялостна UVM среда.
9. Съществуват executable UVM test класове, например `qc_smoke_test`, `qc_single_gate_test`, `qc_measure_test`, `qc_branch_test`, `qc_random_test` и algorithmic workload tests.
10. Съществува `uvm/tb_qc_uvm_top.sv`, който инстанцира `quantum_controller_top`, interface-а и стартира `run_test()`.
11. Съществува `scripts/run_uvm.sh` или еквивалентен run flow за избрания UVM-capable simulator.
12. Има реални UVM logs в `results/uvm_logs/`.
13. Има waveform artifacts за ключови сценарии, например в `results/uvm_waveforms/`.
14. Има coverage artifacts или поне coverage summary за основните functional coverage групи.
15. В раздел 3.8 има попълнена таблица `test name → status → seed → log file → waveform/coverage artifact → какво проверява`.
16. Ясно са описани тестовете, които са минали, тестовете, които не са изпълнени, и ограниченията, които остават валидни.

Важно ограничение: ако в локалната среда няма UVM-capable simulator, UVM кодът може да бъде описан като разработен, но не и като симулационно валидиран. В този случай във финалната дисертация трябва да се прави разграничение между написана UVM инфраструктура и реално изпълнена UVM regression проверка.
