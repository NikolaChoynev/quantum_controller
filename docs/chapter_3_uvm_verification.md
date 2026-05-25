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

Към текущия момент Phase C е доведена до пълен UVM scaffold: transaction/sequence item, stimulus generation, driver/interface слой, passive monitor observation слой, scoreboard/reference модел, coverage collector, agent/env слой, executable tests, top-level UVM testbench и run script.

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
uvm/qc_coverage.sv
uvm/qc_agent.sv
uvm/qc_env.sv
uvm/qc_base_test.sv
uvm/qc_directed_tests.sv
uvm/qc_random_tests.sv
uvm/qc_algorithmic_tests.sv
uvm/tb_qc_uvm_top.sv
scripts/run_uvm.sh
```

UVM кодът все още не е изпълняван срещу DUT като пълна UVM симулация, защото в локалния toolchain няма потвърден UVM-capable simulator. `scripts/run_uvm.sh` е подготвен за Questa/ModelSim, Xcelium или VCS и не трябва да се използва за твърдение на PASS, докато няма реален run.

---

## 3.0.1 Контролен списък за финалното писане на Глава 3

Тази таблица отговаря директно на изискванията за информация, която трябва да присъства в Markdown файла и после във финалното писане на главата.

| № | Изисквана информация | Текущ статус | Къде се попълва |
|---:|---|---|---|
| 1 | Каква UVM среда е реализирана | Налични са package, transaction item, observation item, sequencer, sequences, interface, driver, monitor, scoreboard, coverage, agent, env, test класове, top-level testbench и run script | Раздели 3.2, 3.4, 3.5, 3.6 и 3.7 |
| 2 | Кои файлове са създадени в `uvm/` | Създадени са всички C8/C9 UVM scaffold файлове, включително `tb_qc_uvm_top.sv` | Раздел 3.2 |
| 3 | Как DUT е свързан към testbench-а | Реализирано чрез `qc_if.sv` и `uvm/tb_qc_uvm_top.sv`; реален simulator run предстои | Раздел 3.3 |
| 4 | Какво съдържа transaction/sequence item | Реализирано в `uvm/qc_sequence_item.sv` | Раздел 3.4 |
| 5 | Как работят sequencer, driver, monitor, scoreboard и coverage | Sequencer, sequences, driver, monitor, scoreboard и coverage са реализирани и свързани чрез agent/env | Раздел 3.5 |
| 6 | Какви directed tests са реализирани | Има directed sequence класове и executable directed UVM test класове | Раздел 3.6.1 |
| 7 | Какви constrained-random/stress tests са реализирани | Има random/stress sequence класове и executable random/stress UVM test класове; още не са изпълнявани | Раздел 3.6.2 |
| 8 | Какви algorithmic workloads са реализирани | Има Bell, GHZ и Grover-like sequence класове и executable algorithmic UVM test класове; още не са изпълнявани | Раздел 3.6.3 |
| 9 | Как се пускат симулациите | RTL baseline се пуска с `scripts/run_verilator.sh`; UVM flow е подготвен чрез `scripts/run_uvm.sh`, но изисква UVM-capable simulator | Раздел 3.7 |
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

Към момента тази методология е заложена в плана и кодовият scaffold е реализиран до executable test/top/run flow. Следващата стъпка не е нов UVM слой, а реално изпълнение с UVM-capable simulator и събиране на logs, waveforms и coverage artifacts за Глава 4.

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
| `uvm/qc_coverage.sv` | Реализиран | Functional coverage subscriber върху `qc_observation_item` потока |
| `uvm/qc_agent.sv` | Реализиран | UVM agent, който свързва sequencer, driver и monitor |
| `uvm/qc_env.sv` | Реализиран | UVM environment, който свързва agent, scoreboard и coverage |
| `uvm/qc_base_test.sv` | Реализиран | Base UVM test, който създава env, задава `vif` и управлява objections/drain |
| `uvm/qc_directed_tests.sv` | Реализиран | Directed executable UVM tests |
| `uvm/qc_random_tests.sv` | Реализиран | Random и dependency stress executable UVM tests |
| `uvm/qc_algorithmic_tests.sv` | Реализиран | Bell, GHZ и Grover-like executable UVM tests |
| `uvm/tb_qc_uvm_top.sv` | Реализиран | Top-level UVM testbench, който инстанцира DUT, `qc_if` и стартира `run_test()` |
| `scripts/run_uvm.sh` | Реализиран | UVM run script за Questa/ModelSim, Xcelium или VCS |

Все още няма липсващи C8/C9 scaffold файлове. Остават реални simulator runs и резултатни артефакти.

```text
няма липсващи C8/C9 UVM scaffold файлове
```

Този списък отразява C8/C9 scaffold състоянието. Следващите промени вече трябва да бъдат насочени към реално изпълнение, резултати и евентуални корекции след simulator bring-up.

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
    `include "qc_coverage.sv"
    `include "qc_agent.sv"
    `include "qc_env.sv"
    `include "qc_base_test.sv"
    `include "qc_directed_tests.sv"
    `include "qc_random_tests.sv"
    `include "qc_algorithmic_tests.sv"

endpackage : qc_uvm_pkg
```

Тази структура означава, че UVM класовете не дефинират собствен instruction format. Вместо това те използват същите параметри, opcode enum-и и field width дефиниции от `rtl/qc_pkg.sv`, които се използват и от DUT. Файлът `uvm/qc_if.sv` не е include-нат в package-а, защото SystemVerilog interface е design element и трябва да се компилира отделно преди `uvm/qc_uvm_pkg.sv`.

---

# 3.3 DUT интерфейс и свързване към UVM testbench

Свързването на DUT към UVM testbench е реализирано чрез `uvm/qc_if.sv` и `uvm/tb_qc_uvm_top.sv`. SystemVerilog interface-ът описва сигналите на `rtl/quantum_controller_top.sv`, предоставя clocking block за driver-а, clocking block за monitor-а и `dut` modport за top-level UVM testbench.

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

Реализираното UVM свързване е:

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

SystemVerilog interface-ът, driver-ът, monitor-ът, scoreboard-ът, coverage collector-ът, UVM agent/env слоят, base test-ът, executable tests и top-level testbench вече са реализирани. Следващата стъпка е реален simulator run и събиране на log/waveform/coverage артефакти.

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

Този раздел описва реализираните stimulus generation, driver, monitor, scoreboard, coverage, agent и env компоненти, както и следващите планирани UVM блокове. Към момента sequencer-ът, sequence класовете, virtual interface-ът, driver-ът, monitor-ът, scoreboard-ът, coverage collector-ът, agent-ът и env-ът са реализирани, но executable UVM tests и top-level UVM testbench все още предстоят.

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

Файлът `uvm/qc_sequences.sv` съдържа базов sequence клас и набор от начални directed, constrained-random, stress и algorithmic sequences. Тези класове генерират `qc_sequence_item` обекти и вече са обвити в executable UVM test класове, но още не са изпълнявани срещу DUT поради липса на потвърден UVM-capable simulator.

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

Този sequence е stimulus основата на `qc_smoke_test`, защото преминава през gate path, measurement path и feedback path.

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

Този sequence е основата за `qc_random_test` и бъдещи random regression тестове. След реален UVM simulator run той ще може да се използва за проверка на по-дълги валидни instruction streams и за натрупване на functional coverage.

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

Driver-ът получава virtual interface чрез `uvm_config_db`. Реализираният `qc_agent` получава `vif` и го препраща към driver-а и monitor-а, а `uvm/tb_qc_uvm_top.sv` задава същия interface към UVM test слоя преди `run_test()`.

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

Този код превръща sequence item stream-а в реално driver поведение. Agent/env/top слоят вече е реализиран; остава реално изпълнение с UVM-capable simulator, за да се потвърди поведението срещу DUT.

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

Това е същият `vif` pattern като при driver-а. Реализираният `qc_agent` задава един и същ virtual interface към driver-а и monitor-а, а monitor-ът подава наблюденията към scoreboard и coverage чрез `analysis_port`.

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

На този етап monitor-ът е code-complete като UVM компонент и е свързан през agent/env слоя, но не е изпълняван в реална UVM симулация. Причината е toolchain ограничение: липсва потвърден UVM-capable simulator flow. Минималната текуща проверка е:

```text
1. `uvm/qc_uvm_pkg.sv` include-ва `qc_observation_item.sv` преди `qc_monitor.sv`.
2. `qc_monitor.sv` използва същия `virtual qc_if` pattern като driver-а.
3. Monitor-ът публикува само през `uvm_analysis_port #(qc_observation_item)`.
4. Няма claim за PASS UVM simulation, докато не се изпълни реален simulator run.
```

След C7 `qc_agent.sv` и `qc_env.sv` вече свързват `monitor.analysis_port` към scoreboard и coverage subscribers. След C8/C9 съществуват и base test/top-level testbench, така че реалната практическа проверка остава UVM-capable simulator run.

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

Scoreboard-ът е консервативен: той проверява причинно-следствени отношения между наблюдавани събития, но не твърди пълна cycle-accurate симулация на scheduler-а. Това е правилно за текущия етап, защото UVM средата все още не е пускана в реален UVM-capable simulator.

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

В `check_phase()` scoreboard-ът не маркира автоматично non-empty expected queues като грешка, а ги отчита като warnings. Причината е, че реалното pipeline drain поведение още не е потвърдено с UVM simulator. След първите runs тези warnings могат да бъдат затегнати към errors за тестове, които трябва да drain-нат pipeline-а.

## Как се проверява C5

На този етап `qc_scoreboard.sv` е реализиран като UVM checking компонент и е свързан в `qc_env.sv`. Минималната текуща проверка е:

```text
1. `uvm/qc_uvm_pkg.sv` include-ва `qc_scoreboard.sv` след `qc_monitor.sv`.
2. Scoreboard-ът приема `qc_observation_item` през `uvm_analysis_imp`.
3. Има отделни handlers за всички observation kind стойности от monitor-а.
4. Reference моделът покрива instruction/issue/command, measurement и feedback/status проверки.
5. Няма claim за PASS UVM simulation, докато не се изпълни реален simulator run.
```

След C7 `qc_agent.sv` и `qc_env.sv` вече свързват `monitor.analysis_port` към `scoreboard.analysis_export` и coverage subscriber-а.

## 3.5.6 Coverage

Реализиран файл:

```text
uvm/qc_coverage.sv
```

Coverage моделът е реализиран като `uvm_subscriber #(qc_observation_item)`. Това означава, че той използва същия observation поток като scoreboard-а и отчита реално наблюдавани DUT събития, а не само генериран stimulus.

```text
qc_monitor
→ qc_observation_item stream
→ qc_coverage
```

Coverage компонентът измерва не само opcode покритие, а и важни cross сценарии:

| Coverage категория | Примерни bins/cross |
|---|---|
| Opcode coverage | NOP, H, X, Z, CNOT, MEASURE, WAIT, RESET, BRANCH, INVALID |
| Flag coverage | valid, conditional, feedback, expected |
| Opcode × flags | BRANCH × conditional/feedback/expected |
| Measurement coverage | measurement request, result value 0/1, busy behavior |
| Branch coverage | taken, not taken, missing measurement |
| Scheduler coverage | stall, no-stall, dependency hazard, WAIT hold |
| Queue/busy coverage | empty, non-empty, full-or-more, busy qubit count |
| Command coverage | opcode × command class |

Алгоритмичните workload-и, като Bell, GHZ и Grover-like, ще се виждат чрез opcode/command/measurement/feedback покритието, когато бъдат добавени executable UVM tests. На този етап няма отделен workload label в `qc_observation_item`, затова coverage моделът не твърди самостоятелни bins за test name или sequence name.

## Кодов фрагмент 3.29 – Coverage subscriber и sampled state

От `uvm/qc_coverage.sv`:

```systemverilog
class qc_coverage extends uvm_subscriber #(qc_observation_item);

    qc_observation_kind_e sampled_kind;
    qc_opcode_e           sampled_opcode;
    qc_command_class_e    sampled_command_class;

    bit                   sampled_valid_flag;
    bit                   sampled_conditional_flag;
    bit                   sampled_feedback_flag;
    bit                   sampled_expected_flag;

    bit                   sampled_measure_request;
    bit                   sampled_measure_response;
    bit                   sampled_measure_response_value;
    bit                   sampled_measure_result;
    bit                   sampled_measure_result_value;
    bit                   sampled_measurement_busy;
```

Coverage класът не работи директно със signal-level интерфейса. Той първо преобразува `qc_observation_item` към sampled state променливи, а covergroup-ите семплират тези стабилни променливи.

## Кодов фрагмент 3.30 – Opcode и flag coverage

Instruction coverage групата покрива всички opcode-и от `qc_pkg.sv`, invalid/default opcode случаи, valid flag и branch-related flags.

```systemverilog
covergroup instruction_cg with function sample();
    option.per_instance = 1;

    opcode_cp: coverpoint sampled_opcode {
        bins nop     = {OP_NOP};
        bins h       = {OP_H};
        bins x       = {OP_X};
        bins z       = {OP_Z};
        bins cnot    = {OP_CNOT};
        bins measure = {OP_MEASURE};
        bins wait_op = {OP_WAIT};
        bins reset   = {OP_RESET};
        bins branch  = {OP_BRANCH};
        bins invalid = default;
    }

    valid_flag_cp: coverpoint sampled_valid_flag {
        bins invalid_flag = {0};
        bins valid_flag   = {1};
    }

    conditional_flag_cp: coverpoint sampled_conditional_flag {
        bins off = {0};
        bins on  = {1};
    }

    feedback_flag_cp: coverpoint sampled_feedback_flag {
        bins off = {0};
        bins on  = {1};
    }

    expected_flag_cp: coverpoint sampled_expected_flag {
        bins expected_zero = {0};
        bins expected_one  = {1};
    }

    opcode_x_valid: cross opcode_cp, valid_flag_cp;
    branch_x_flags: cross opcode_cp, conditional_flag_cp, feedback_flag_cp, expected_flag_cp;
endgroup
```

Това покритие е важно за финалната дисертация, защото показва как ще се измерва дали тестовете преминават през всички instruction класове и branch флагови комбинации.

## Кодов фрагмент 3.31 – Command class coverage

Coverage моделът дефинира отделен command classification enum, който нормализира `gate_cmd`, `measure_cmd`, `wait_cmd`, `reset_cmd`, `branch_cmd` и `nop_cmd`.

```systemverilog
typedef enum int unsigned {
    QC_CMD_CLASS_NONE,
    QC_CMD_CLASS_GATE,
    QC_CMD_CLASS_MEASURE,
    QC_CMD_CLASS_WAIT,
    QC_CMD_CLASS_RESET,
    QC_CMD_CLASS_BRANCH,
    QC_CMD_CLASS_NOP,
    QC_CMD_CLASS_MULTI
} qc_command_class_e;

covergroup command_cg with function sample();
    option.per_instance = 1;

    opcode_cp: coverpoint sampled_opcode {
        bins nop     = {OP_NOP};
        bins gates   = {OP_H, OP_X, OP_Z, OP_CNOT};
        bins measure = {OP_MEASURE};
        bins wait_op = {OP_WAIT};
        bins reset   = {OP_RESET};
        bins branch  = {OP_BRANCH};
        bins invalid = default;
    }

    command_class_cp: coverpoint sampled_command_class {
        bins none    = {QC_CMD_CLASS_NONE};
        bins gate    = {QC_CMD_CLASS_GATE};
        bins measure = {QC_CMD_CLASS_MEASURE};
        bins wait_op = {QC_CMD_CLASS_WAIT};
        bins reset   = {QC_CMD_CLASS_RESET};
        bins branch  = {QC_CMD_CLASS_BRANCH};
        bins nop     = {QC_CMD_CLASS_NOP};
        bins multi   = {QC_CMD_CLASS_MULTI};
    }

    opcode_x_command_class: cross opcode_cp, command_class_cp;
endgroup
```

`QC_CMD_CLASS_MULTI` е defensive coverage bin. Ако някога повече от един command class bit е активен едновременно, scoreboard-ът трябва да даде грешка, а coverage моделът ще покаже, че е наблюдаван такъв случай.

## Кодов фрагмент 3.32 – Measurement и feedback coverage

Measurement coverage групата покрива request, response, result, result value и unexpected path. Feedback coverage групата покрива taken/not-taken, checked/unchecked condition, missing measurement и feedback value.

```systemverilog
covergroup measurement_cg with function sample();
    option.per_instance = 1;

    request_cp: coverpoint sampled_measure_request {
        bins no_request = {0};
        bins request    = {1};
    }

    response_cp: coverpoint sampled_measure_response {
        bins no_response = {0};
        bins response    = {1};
    }

    result_cp: coverpoint sampled_measure_result {
        bins no_result = {0};
        bins result    = {1};
    }

    response_x_value: cross response_cp, response_value_cp;
    result_x_value:   cross result_cp, result_value_cp;
endgroup

covergroup feedback_cg with function sample();
    option.per_instance = 1;

    branch_taken_cp: coverpoint sampled_branch_taken {
        bins not_taken = {0};
        bins taken     = {1};
    }

    missing_measurement_cp: coverpoint sampled_missing_measurement {
        bins present = {0};
        bins missing = {1};
    }

    branch_outcome_x_condition: cross branch_taken_cp,
                                      condition_checked_cp,
                                      missing_measurement_cp;
endgroup
```

Това покритие е пряко свързано с най-важните feedback сценарии в контролера: measurement result 0/1, branch taken/not-taken и conditional branch без наличен measurement резултат.

## Кодов фрагмент 3.33 – Status, queue и busy coverage

Status coverage групата следи stall/error/debug състоянията и ги комбинира с queue/busy състояния.

```systemverilog
covergroup status_cg with function sample();
    option.per_instance = 1;

    stall_cp: coverpoint sampled_scheduler_stall {
        bins no_stall = {0};
        bins stall    = {1};
    }

    illegal_instr_cp: coverpoint sampled_illegal_instr {
        bins legal_path   = {0};
        bins illegal_path = {1};
    }

    queue_count_cp: coverpoint sampled_queue_count {
        bins empty        = {0};
        bins non_empty    = {[1:3]};
        bins full_or_more = {[4:16]};
    }

    busy_count_cp: coverpoint sampled_busy_count {
        bins none = {0};
        bins one  = {1};
        bins few  = {[2:4]};
        bins many = {[5:16]};
    }

    stall_x_queue: cross stall_cp, queue_count_cp;
    stall_x_busy:  cross stall_cp, busy_count_cp;
endgroup
```

Тези coverpoints ще бъдат полезни за бъдещата Глава 4, защото позволяват да се отчете дали regression тестовете реално са достигнали stall, queue pressure и multi-qubit busy състояния.

## Кодов фрагмент 3.34 – Sampling dispatch

`write()` методът избира кои covergroups да бъдат семплирани според observation kind-а.

```systemverilog
function void write(qc_observation_item t);
    sample_common(t);
    observation_cg.sample();

    case (t.kind)
        QC_OBS_INSTRUCTION,
        QC_OBS_ISSUE: begin
            instruction_samples++;
            instruction_cg.sample();
        end

        QC_OBS_COMMAND: begin
            command_samples++;
            instruction_cg.sample();
            command_cg.sample();
        end

        QC_OBS_MEASURE_REQUEST,
        QC_OBS_MEASURE_RESPONSE,
        QC_OBS_MEASURE_RESULT: begin
            measurement_samples++;
            measurement_cg.sample();
        end

        QC_OBS_FEEDBACK: begin
            feedback_samples++;
            feedback_cg.sample();
        end

        QC_OBS_STATUS: begin
            status_samples++;
            status_cg.sample();
        end
    endcase
endfunction
```

## Как се проверява C6

На този етап `qc_coverage.sv` е реализиран като UVM coverage subscriber и е свързан в `qc_env.sv`. Минималната текуща проверка е:

```text
1. `uvm/qc_uvm_pkg.sv` include-ва `qc_coverage.sv` след `qc_scoreboard.sv`.
2. Coverage компонентът наследява `uvm_subscriber #(qc_observation_item)`.
3. Covergroup-ите покриват opcode, flags, command class, measurement, feedback и status/queue/busy състояния.
4. Няма claim за coverage процент или PASS UVM simulation, докато не се изпълни реален simulator run.
```

## 3.5.7 Agent и Environment

Реализирани файлове:

```text
uvm/qc_agent.sv
uvm/qc_env.sv
```

C7 добавя първото реално UVM свързване между вече написаните компоненти. До този момент sequencer, driver, monitor, scoreboard и coverage съществуваха като отделни класове. След C7 те вече са организирани в стандартна UVM agent/env структура:

```text
qc_env
→ qc_agent
  → qc_sequencer
  → qc_driver
  → qc_monitor
→ qc_scoreboard
→ qc_coverage
```

`qc_agent` е active/passive компонент. В active режим той създава sequencer, driver и monitor и свързва `driver.seq_item_port` към `sequencer.seq_item_export`. В passive режим се създава само monitor, което позволява бъдещо наблюдение без stimulus driving.

`qc_env` създава agent, scoreboard и coverage, след което свързва monitor analysis stream-а към checking и coverage компонентите.

## Кодов фрагмент 3.35 – Agent build и active/passive режим

От `uvm/qc_agent.sv`:

```systemverilog
class qc_agent extends uvm_agent;

    qc_sequencer sequencer;
    qc_driver    driver;
    qc_monitor   monitor;

    virtual qc_if vif;
    bit           has_vif;

    `uvm_component_utils(qc_agent)

    function new(string name = "qc_agent", uvm_component parent = null);
        super.new(name, parent);
        is_active = UVM_ACTIVE;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db #(uvm_active_passive_enum)::get(
            this,
            "",
            "is_active",
            is_active
        ));

        has_vif = uvm_config_db #(virtual qc_if)::get(this, "", "vif", vif);
```

Agent-ът може да получи `vif` чрез `uvm_config_db`. Ако interface-ът е зададен на agent ниво, agent-ът го препраща към driver-а и monitor-а. Това намалява нуждата test класовете да задават `vif` към всеки child компонент поотделно.

## Кодов фрагмент 3.36 – Agent component creation и sequencer-driver връзка

```systemverilog
        monitor = qc_monitor::type_id::create("monitor", this);

        if (is_active == UVM_ACTIVE) begin
            sequencer = qc_sequencer::type_id::create("sequencer", this);
            driver    = qc_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (is_active == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
```

Това е ключовата UVM stimulus връзка: sequence класовете ще стартират върху `agent.sequencer`, а driver-ът ще получава `qc_sequence_item` през стандартния UVM `seq_item_port`.

## Кодов фрагмент 3.37 – Environment build

От `uvm/qc_env.sv`:

```systemverilog
class qc_env extends uvm_env;

    qc_agent      agent;
    qc_scoreboard scoreboard;
    qc_coverage   coverage;

    bit enable_scoreboard = 1'b1;
    bit enable_coverage   = 1'b1;

    `uvm_component_utils(qc_env)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent = qc_agent::type_id::create("agent", this);

        if (enable_scoreboard) begin
            scoreboard = qc_scoreboard::type_id::create("scoreboard", this);
        end

        if (enable_coverage) begin
            coverage = qc_coverage::type_id::create("coverage", this);
        end
    endfunction
```

Env-ът има конфигурационни флагове `enable_scoreboard` и `enable_coverage`, за да могат бъдещи smoke/debug тестове временно да изключват checking или coverage, ако това е нужно при bring-up.

## Кодов фрагмент 3.38 – Environment analysis връзки

```systemverilog
function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (enable_scoreboard) begin
        agent.monitor.analysis_port.connect(scoreboard.analysis_export);
    end

    if (enable_coverage) begin
        agent.monitor.analysis_port.connect(coverage.analysis_export);
    end
endfunction
```

Тази връзка затваря основния observation/checking/coverage път:

```text
DUT signals
→ qc_if.mon_cb
→ qc_monitor
→ qc_observation_item
→ qc_scoreboard
→ qc_coverage
```

След C7 UVM средата получи структурно свързан active agent и environment. В следващите стъпки C8/C9 вече са добавени base test, executable test класове, top-level testbench и run script, така че остава simulator bring-up и реална UVM regression проверка.

## Как се проверява C7

Минималната текуща проверка е:

```text
1. `uvm/qc_uvm_pkg.sv` include-ва `qc_agent.sv` и `qc_env.sv`.
2. `qc_agent.sv` създава monitor винаги, а sequencer/driver само в active режим.
3. `qc_agent.sv` свързва `driver.seq_item_port` към `sequencer.seq_item_export`.
4. `qc_env.sv` създава agent, scoreboard и coverage.
5. `qc_env.sv` свързва monitor analysis port-а към scoreboard и coverage.
6. Няма claim за PASS UVM simulation, докато не се изпълни реален UVM run с подходящ simulator.
```

---

# 3.6 Test plan

## 3.6.1 Directed tests

Вече са реализирани executable UVM directed test класове. Те наследяват `qc_base_test`, създават конкретен sequence и го стартират върху `env.agent.sequencer`. Top-level testbench и run script също са реализирани; тестовете все още не са изпълнявани, защото в локалния toolchain няма потвърден UVM-capable simulator.

## Кодов фрагмент 3.39 – Base test

От `uvm/qc_base_test.sv`:

```systemverilog
class qc_base_test extends uvm_test;

    qc_env        env;
    virtual qc_if vif;

    int unsigned drain_cycles = 64;

    `uvm_component_utils(qc_base_test)

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual qc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface 'vif' was not provided")
        end

        uvm_config_db #(virtual qc_if)::set(this, "env.agent", "vif", vif);

        env = qc_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        run_test_sequence();
        drain_pipeline();

        phase.drop_objection(this);
    endtask
```

Base test-ът е обща основа за всички executable tests. Той получава virtual interface-а от top-level testbench-а, препраща го към `env.agent`, създава `qc_env` и управлява UVM objections. Методът `run_test_sequence()` е virtual hook, който конкретните test класове override-ват.

## Кодов фрагмент 3.40 – Directed test wrapper

От `uvm/qc_directed_tests.sv`:

```systemverilog
class qc_smoke_test extends qc_base_test;

    `uvm_component_utils(qc_smoke_test)

    virtual task run_test_sequence();
        qc_smoke_sequence seq;

        seq = qc_smoke_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_smoke_test
```

Всички directed tests следват същия модел: test класът избира sequence, създава го чрез UVM factory и го стартира върху agent sequencer-а.

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

Текущите directed tests покриват следните сценарии:

| Test | Sequence | Покрит сценарий |
|---|---|---|
| `qc_smoke_test` | `qc_smoke_sequence` | H → MEASURE → conditional BRANCH |
| `qc_single_gate_test` | `qc_single_gate_sequence` | H, X и Z |
| `qc_cnot_test` | `qc_cnot_sequence` | H + CNOT |
| `qc_measure_test` | `qc_measure_sequence` | MEASURE с measurement response metadata |
| `qc_wait_test` | `qc_wait_sequence` | WAIT между две gate операции |
| `qc_branch_test` | `qc_branch_sequence` | MEASURE + conditional branch + по-млада инструкция |
| `qc_invalid_opcode_test` | `qc_invalid_opcode_sequence` | Raw invalid opcode |

Подробният test plan за тези тестове е отделен в:

```text
docs/chapter_3_uvm_test_plan.tpl.md
```

## 3.6.2 Constrained-random и stress tests

Вече има executable UVM constrained-random и stress test класове, но те още не са изпълнявани в симулация.

Реализирани tests:

| Test | Sequence | Описание |
|---|---|---|
| `qc_random_test` | `qc_random_instruction_sequence` | Random opcode, qubit, duration и flag комбинации с валиден instruction format |
| `qc_dependency_stress_test` | `qc_dependency_stress_sequence` | Операции върху едни и същи qubit ресурси за dependency/stall stimulus |

## Кодов фрагмент 3.41 – Random test с configurable item_count

От `uvm/qc_random_tests.sv`:

```systemverilog
class qc_random_test extends qc_base_test;

    int unsigned item_count = 48;

    `uvm_component_utils(qc_random_test)

    virtual task run_test_sequence();
        qc_random_instruction_sequence seq;

        seq = qc_random_instruction_sequence::type_id::create("seq");
        seq.item_count = item_count;
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_random_test
```

Остават за бъдещо разширяване:

| Направление | Описание |
|---|---|
| Queue pressure | Дълги instruction bursts за full/non-empty queue състояния |
| Measurement latency variation | Различни latency стойности за measurement result подаване |
| Branch feedback variation | Conditional branch с expected 0/1 и measurement 0/1 |
| Illegal injection | По-богато контролирано вкарване на invalid opcode/raw malformed инструкции |
| Long WAIT stress | WAIT операции с различна продължителност |

## 3.6.3 Algorithmic workloads

Вече има реализирани executable UVM test класове за начални algorithmic workloads, но те все още не са изпълнявани срещу DUT.

Реализираните algorithmic tests са:

| Test | Sequence | Instruction идея | Цел |
|---|---|---|---|
| `qc_bell_test` | `qc_algorithmic_bell_sequence` | H върху q0, CNOT q0→q1, measurement | Проверка на зависимост между еднокубитна и двукубитна операция |
| `qc_ghz_test` | `qc_algorithmic_ghz_sequence` | H върху q0, CNOT chain, measurements | Проверка на последователни multi-qubit зависимости |
| `qc_grover_like_test` | `qc_algorithmic_grover_like_sequence` | H/X/Z/CNOT/MEASURE/conditional BRANCH pattern | Проверка на смесени gate и feedback сценарии |

## Кодов фрагмент 3.42 – Algorithmic test wrapper

От `uvm/qc_algorithmic_tests.sv`:

```systemverilog
class qc_bell_test extends qc_base_test;

    `uvm_component_utils(qc_bell_test)

    function new(string name = "qc_bell_test", uvm_component parent = null);
        super.new(name, parent);
        drain_cycles = 96;
    endfunction

    virtual task run_test_sequence();
        qc_algorithmic_bell_sequence seq;

        seq = qc_algorithmic_bell_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_bell_test
```

Остават за бъдещо добавяне:

| Workload | Цел |
|---|---|
| Measurement-feedback workload variants | Повече комбинации от expected/result branch outcomes |
| Random-circuit-inspired workload | По-дълги random gate streams върху различни qubit-и |

Тези workloads са алгоритмично мотивирани. Те не трябва да се описват като физическа квантова симулация или като възпроизвеждане на реален quantum backend.

## 3.6.4 Top-level UVM testbench и run flow

Реализирани файлове:

```text
uvm/tb_qc_uvm_top.sv
scripts/run_uvm.sh
```

`uvm/tb_qc_uvm_top.sv` е top-level simulation wrapper за UVM средата. Той генерира clock, инстанцира `qc_if`, свързва `rtl/quantum_controller_top.sv` към interface сигналите, задава `virtual qc_if` през `uvm_config_db` и стартира UVM test чрез `run_test()`.

## Кодов фрагмент 3.43 – Top-level DUT и interface инстанциране

От `uvm/tb_qc_uvm_top.sv`:

```systemverilog
qc_if #(
    .QUEUE_DEPTH(QUEUE_DEPTH),
    .NUM_QUBITS(NUM_QUBITS)
) qc_vif (
    .clk_i(clk_i)
);

quantum_controller_top #(
    .QUEUE_DEPTH(QUEUE_DEPTH),
    .NUM_QUBITS(NUM_QUBITS)
) dut (
    .clk_i      (qc_vif.clk_i),
    .rst_ni     (qc_vif.rst_ni),
    .instr_i    (qc_vif.instr_i),
    .instr_valid_i(qc_vif.instr_valid_i),
    .instr_ready_o(qc_vif.instr_ready_o),
    .measurement_result_valid_i(qc_vif.measurement_result_valid_i),
    .measurement_result_i      (qc_vif.measurement_result_i)
);
```

В реалния файл са свързани и всички issue, command, measurement, feedback и status/debug изходи на DUT. Този top-level wrapper е мостът между RTL модула и UVM component слоя.

## Кодов фрагмент 3.44 – Подаване на virtual interface и стартиране на UVM test

От `uvm/tb_qc_uvm_top.sv`:

```systemverilog
initial begin
    uvm_config_db #(virtual qc_if)::set(null, "uvm_test_top", "vif", qc_vif);
    run_test();
end
```

Това позволява `qc_base_test` да получи `vif`, да го зададе към `env.agent` и така driver-ът и monitor-ът да работят върху един и същ interface към DUT.

`scripts/run_uvm.sh` е първият run flow за UVM фазата. Той не използва Verilator за UVM, а очаква UVM-capable simulator.

## Кодов фрагмент 3.45 – Списък на executable UVM tests в run script-а

От `scripts/run_uvm.sh`:

```bash
TESTS=(
    qc_smoke_test
    qc_single_gate_test
    qc_cnot_test
    qc_measure_test
    qc_wait_test
    qc_branch_test
    qc_invalid_opcode_test
    qc_random_test
    qc_dependency_stress_test
    qc_bell_test
    qc_ghz_test
    qc_grover_like_test
)
```

Този списък трябва да остане синхронизиран с `uvm/qc_directed_tests.sv`, `uvm/qc_random_tests.sv`, `uvm/qc_algorithmic_tests.sv` и `docs/chapter_3_uvm_test_plan.tpl.md`.

## Кодов фрагмент 3.46 – Simulator detection и отказ при липса на UVM simulator

От `scripts/run_uvm.sh`:

```bash
if command -v vlog >/dev/null 2>&1 && command -v vsim >/dev/null 2>&1; then
    echo "questa"
    return
fi

if command -v xrun >/dev/null 2>&1; then
    echo "xcelium"
    return
fi

if command -v vcs >/dev/null 2>&1; then
    echo "vcs"
    return
fi

echo "none"
```

Ако не бъде намерен Questa/ModelSim, Xcelium или VCS, script-ът приключва с ясна грешка и не твърди PASS:

```text
No UVM-capable simulator found in PATH.
This script does not run UVM with Verilator.
```

За Глава 4 това е важно методологично ограничение: UVM кодът може да бъде описан като реализиран, но резултати като PASS, waveform и coverage могат да се включват само след реален run с такъв simulator.

## Как се проверява C9

Минималната текуща проверка на C9 е:

```text
1. `uvm/tb_qc_uvm_top.sv` инстанцира `qc_if` и `quantum_controller_top`.
2. DUT входовете и изходите са свързани към interface сигналите.
3. `uvm_config_db #(virtual qc_if)::set(...)` задава `vif` към `uvm_test_top`.
4. `run_test()` стартира test класа, избран чрез `+UVM_TESTNAME`.
5. `scripts/run_uvm.sh --list` показва всички executable UVM tests.
6. `scripts/run_uvm.sh` отказва изпълнение без Questa/ModelSim, Xcelium или VCS и не използва Verilator за UVM.
7. Няма claim за PASS UVM simulation, докато не се създадат реални logs/waves/coverage artifacts.
```

---

# 3.7 Стартиране на симулации

Към момента има два различни simulation flow-а:

```bash
./scripts/run_verilator.sh all
./scripts/run_uvm.sh --list
```

`scripts/run_verilator.sh` проверява non-UVM RTL testbench-ите в `tb/`. Той остава важен baseline, но не изпълнява UVM средата.

`scripts/run_uvm.sh` е подготвен за UVM flow и поддържа:

```text
UVM_SIM=auto|questa|xcelium|vcs
SEED=<integer>
TIMEOUT_CYCLES=<integer>
DUMP_VCD=0|1
```

Примерни команди за бъдещ UVM-capable simulator setup:

```bash
./scripts/run_uvm.sh --list
UVM_SIM=questa SEED=1 ./scripts/run_uvm.sh qc_smoke_test
UVM_SIM=questa SEED=1 ./scripts/run_uvm.sh all
```

Script-ът създава директории за резултати:

```text
results/uvm_logs/
results/uvm_waveforms/
results/uvm_coverage/
```

Проверка на наличните simulator команди към момента показа:

```text
verilator: наличен
vlog/vsim: не са налични в PATH
xrun: не е наличен в PATH
vcs: не е наличен в PATH
```

Тъй като класическа UVM среда обикновено изисква UVM-capable simulator като Questa/ModelSim, VCS или Xcelium, към момента UVM кодът не е изпълнен в симулация. Това трябва да бъде описано като текущо toolchain ограничение, докато не бъде добавен или конфигуриран подходящ simulator.

`scripts/run_uvm.sh` компилира следните RTL и UVM entry files:

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
uvm/qc_if.sv
uvm/qc_uvm_pkg.sv
uvm/tb_qc_uvm_top.sv
```

и стартира избран UVM test чрез `+UVM_TESTNAME=...`.

Файловете `qc_sequence_item.sv`, `qc_observation_item.sv`, `qc_sequencer.sv`, `qc_sequences.sv`, `qc_driver.sv`, `qc_monitor.sv`, `qc_scoreboard.sv`, `qc_coverage.sv`, `qc_agent.sv`, `qc_env.sv`, `qc_base_test.sv`, `qc_directed_tests.sv`, `qc_random_tests.sv` и `qc_algorithmic_tests.sv` се включват през `uvm/qc_uvm_pkg.sv`, затова run script-ът трябва да подаде правилен include path към директорията `uvm/`.

---

# 3.8 Logs, waveforms и coverage резултати

Към момента няма валидирани UVM-generated logs, waveforms или coverage reports, защото UVM testbench-ът и run script-ът са реализирани, но все още не са изпълнени с UVM-capable simulator.

Наличните резултати от проекта са от RTL Verilator regression flow:

```text
results/simulation_logs/
results/waveforms/
```

Тези резултати могат да се използват като baseline доказателство, че RTL работи преди започване на UVM, но не трябва да се представят като UVM резултати.

При Chapter 4 simulator bring-up тук трябва да се добавят:

| Артефакт | Очаквано съдържание |
|---|---|
| UVM run logs | Pass/fail логове за directed, random и algorithmic tests |
| UVM waveforms | Waveform файлове за key scenarios |
| Coverage reports | Functional coverage summary и missing bins |
| Regression summary | Таблица test → status → seed → log |

Финалната версия на този раздел трябва да съдържа реална regression таблица, а не само описание на планирани тестове. Минималният формат е:

| UVM test | Sequence | Status | Seed | Log | Waveform/Coverage | Какво проверява |
|---|---|---|---:|---|---|---|
| `qc_smoke_test` | `qc_smoke_sequence` | NOT RUN | 1 | `results/uvm_logs/qc_smoke_test.log` | TBD | H → MEASURE → BRANCH |
| `qc_single_gate_test` | `qc_single_gate_sequence` | NOT RUN | 1 | `results/uvm_logs/qc_single_gate_test.log` | TBD | H/X/Z command path |
| `qc_branch_test` | `qc_branch_sequence` | NOT RUN | 1 | `results/uvm_logs/qc_branch_test.log` | TBD | Measurement feedback branch |

Пълният test plan template е:

```text
docs/chapter_3_uvm_test_plan.tpl.md
```

Този `.tpl.md` файл трябва да се използва при подготовката на Глава 4, защото съдържа за всеки тест: цел, sequence, изисквания, scoreboard проверки, coverage цели и очаквани log/waveform/coverage артефакти.

В тази таблица `PASS` може да се запише само след реално изпълнена UVM симулация с UVM-capable simulator. До тогава статусът трябва да остане `TBD`, `NOT RUN` или еквивалентно ясно обозначение.

---

# 3.9 Ограничения на текущата UVM среда

Текущите ограничения са:

1. Реализирани са UVM package, transaction/sequence item, observation item, sequencer, sequence класове, virtual interface, driver, monitor, scoreboard, coverage collector, agent, env, executable test класове, top-level testbench и run script.
2. Няма потвърден UVM-capable simulator в PATH. Verilator е наличен, но се използва само за съществуващите non-UVM RTL testbench-и.
3. Няма реални UVM PASS/FAIL logs, UVM waveforms или UVM coverage reports.
4. `scripts/run_uvm.sh` е подготвен за Questa/ModelSim, Xcelium и VCS, но самият flow не е валидиран върху реална локална инсталация на тези инструменти.
5. Coverage моделът е написан, но coverage проценти и missing bins не могат да се твърдят без реален UVM run.
6. Constrained-random, stress и algorithmic workloads съществуват като sequence и test класове, но все още нямат реални scoreboard/coverage simulation резултати.

Тези ограничения са нормални за текущия етап. Phase C вече е scaffold-complete, а следващият риск е toolchain bring-up и корекция на евентуални simulator-specific проблеми.

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

Следващата реална стъпка след C9 е:

```text
UVM simulator bring-up и първи реални regression runs
```

Препоръчителен ред:

1. Инсталиране или конфигуриране на UVM-capable simulator: Questa/ModelSim, Xcelium или VCS.
2. Изпълнение на `./scripts/run_uvm.sh --list`, за да се потвърди test registry.
3. Първи smoke run: `UVM_SIM=<sim> SEED=1 ./scripts/run_uvm.sh qc_smoke_test`.
4. Ако smoke run-ът мине, изпълнение на directed tests.
5. След това изпълнение на random/stress и algorithmic tests.
6. Попълване на `docs/chapter_3_uvm_test_plan.tpl.md` с реални status, seed, log, waveform и coverage artifacts.
7. Подготовка на Глава 4 с анализ на реалните logs, waveforms и coverage резултати.

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
