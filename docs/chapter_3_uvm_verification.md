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

Към текущия момент е започната Phase C от работния план. Реализирана е началната UVM инфраструктура за transaction/sequence item и stimulus generation слой:

```text
uvm/qc_uvm_pkg.sv
uvm/qc_sequence_item.sv
uvm/qc_sequencer.sv
uvm/qc_sequences.sv
```

Все още не са реализирани driver, monitor, scoreboard, coverage collector, UVM agent/environment, UVM tests или UVM top-level testbench. Sequencer-ът и sequence класовете вече съществуват като UVM код, но все още не са изпълнявани срещу DUT, защото няма driver/interface/env слой.

---

## 3.0.1 Контролен списък за финалното писане на Глава 3

Тази таблица отговаря директно на изискванията за информация, която трябва да присъства в Markdown файла и после във финалното писане на главата.

| № | Изисквана информация | Текущ статус | Къде се попълва |
|---:|---|---|---|
| 1 | Каква UVM среда е реализирана | Започната е UVM среда; налични са package, transaction item, sequencer и sequence classes | Раздели 3.2, 3.4 и 3.5 |
| 2 | Кои файлове са създадени в `uvm/` | Създадени са `qc_uvm_pkg.sv`, `qc_sequence_item.sv`, `qc_sequencer.sv` и `qc_sequences.sv` | Раздел 3.2 |
| 3 | Как DUT е свързан към testbench-а | Все още не е реализирано; описан е планираният интерфейс към `quantum_controller_top` | Раздел 3.3 |
| 4 | Какво съдържа transaction/sequence item | Реализирано в `uvm/qc_sequence_item.sv` | Раздел 3.4 |
| 5 | Как работят sequencer, driver, monitor, scoreboard и coverage | Sequencer и sequences са реализирани; driver/monitor/scoreboard/coverage предстоят | Раздел 3.5 |
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

Към момента тази методология е заложена в плана, като реално имплементирани са transaction/sequence item слой, sequencer и начални sequence класове. Следващият липсващ слой е driver/interface, който трябва да свърже sequence stream-а към реалните DUT сигнали.

---

# 3.2 Реализирана UVM структура към момента

Към момента директорията `uvm/` съдържа следните файлове:

| Файл | Статус | Роля |
|---|---|---|
| `uvm/qc_uvm_pkg.sv` | Реализиран | Общ UVM package, който импортира `uvm_pkg`, `qc_pkg` и включва UVM класовете |
| `uvm/qc_sequence_item.sv` | Реализиран | Transaction/sequence item за генериране на instruction-level stimulus |
| `uvm/qc_sequencer.sv` | Реализиран | Типизиран UVM sequencer за `qc_sequence_item` |
| `uvm/qc_sequences.sv` | Реализиран | Directed, random, stress и algorithmic sequence класове |

Все още не са създадени:

```text
uvm/qc_driver.sv
uvm/qc_monitor.sv
uvm/qc_scoreboard.sv
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
    `include "qc_sequencer.sv"
    `include "qc_sequences.sv"

endpackage : qc_uvm_pkg
```

Тази структура означава, че UVM класовете не дефинират собствен instruction format. Вместо това те използват същите параметри, opcode enum-и и field width дефиниции от `rtl/qc_pkg.sv`, които се използват и от DUT.

---

# 3.3 DUT интерфейс и планирано свързване към UVM testbench

Свързването на DUT към UVM testbench все още не е реализирано. Въпреки това интерфейсът, който трябва да бъде управляван и наблюдаван, вече е ясен от `rtl/quantum_controller_top.sv`.

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

Бъдещият UVM driver трябва да подава `instr_i` само когато sequence item е наличен и DUT приема инструкция чрез `instr_ready_o`. За measurement сценарии UVM средата трябва да подава `measurement_result_valid_i` и `measurement_result_i` след като DUT генерира `measure_request_valid_o`.

Планираното UVM свързване е:

```text
qc_sequence_item
→ qc_sequencer
→ qc_driver
→ virtual interface
→ quantum_controller_top
→ qc_monitor
→ scoreboard + coverage
```

Този слой ще бъде реализиран в следващите стъпки чрез SystemVerilog interface и UVM agent/env компоненти.

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

## Кодов фрагмент 3.3 – Основни полета на transaction item-а

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

## Кодов фрагмент 3.4 – Constraints за валидни инструкции

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

## Кодов фрагмент 3.5 – Пакетиране към реалната 32-битова инструкция

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

## Кодов фрагмент 3.6 – Поддръжка на raw directed инструкции

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

## Кодов фрагмент 3.7 – Measurement response metadata

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

Това не означава, че measurement responder вече е реализиран. То означава, че sequence item-ът вече носи достатъчно информация, за да може следващият driver/responder слой да подаде measurement result след заявка от DUT.

---

# 3.5 UVM компоненти за stimulus generation и планирани следващи блокове

Този раздел описва реализираните stimulus generation компоненти и следващите планирани UVM блокове. Към момента sequencer-ът и sequence класовете са реализирани, но driver, monitor, scoreboard, coverage, agent, environment и executable UVM tests все още предстоят.

## 3.5.1 Sequencer

Реализиран файл:

```text
uvm/qc_sequencer.sv
```

Sequencer-ът е типизиран върху `qc_sequence_item` и предоставя transaction stream към бъдещия driver. Неговата роля е стандартна за UVM active agent: да приема directed или constrained-random sequences и да ги подава към driver-а чрез `seq_item_port`.

## Кодов фрагмент 3.8 – Типизиран UVM sequencer

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

Файлът `uvm/qc_sequences.sv` съдържа базов sequence клас и набор от начални directed, constrained-random, stress и algorithmic sequences. Тези класове генерират `qc_sequence_item` обекти, но още не са изпълнявани срещу DUT, защото driver и UVM testbench top още не са реализирани.

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

## Кодов фрагмент 3.9 – Helper функция за flags

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

## Кодов фрагмент 3.10 – Structured instruction stimulus

Функцията `send_instruction()` създава `qc_sequence_item`, попълва полетата му и обновява `raw_instr`. Бъдещият driver ще получава точно тези item-и през sequencer-а.

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

## Кодов фрагмент 3.11 – Smoke sequence

`qc_smoke_sequence` е минимален end-to-end stimulus шаблон: gate операция, measurement операция и conditional feedback branch.

```systemverilog
virtual task body();
    send_instruction(OP_H,       4'd0, 4'd0, 12'd4,  make_flags());
    send_instruction(OP_MEASURE, 4'd0, 4'd0, 12'd6,  make_flags(), '0, 1'b1, 1'b1, 3);
    send_instruction(OP_BRANCH,  4'd0, 4'd0, 12'd16, make_flags(1'b1, 1'b1, 1'b1, 1'b1));
endtask
```

Този sequence е полезен за първия бъдещ UVM smoke test, защото преминава през gate path, measurement path и feedback path.

## Кодов фрагмент 3.12 – Constrained-random instruction stream

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

Този sequence е основата за бъдещи random regression тестове. След добавяне на driver/monitor/scoreboard той ще може да проверява по-дълги валидни instruction streams.

## Кодов фрагмент 3.13 – Algorithmic Bell workload

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

Планиран файл:

```text
uvm/qc_driver.sv
```

Driver-ът трябва да:

1. Извлича `qc_sequence_item` от sequencer-а.
2. Изчаква `instr_ready_o`.
3. Подава `instr_i = item.pack_raw()`.
4. Активира `instr_valid_i` за един или повече clock cycles според ready/valid протокола.
5. При measurement transaction да изчака `measure_request_valid_o`, след което да подаде `measurement_result_valid_i` и `measurement_result_i` след `measurement_latency_cycles`.

Това поведение все още не е реализирано.

## 3.5.4 Monitor

Планирани файлове:

```text
uvm/qc_monitor.sv
```

Monitor-ът трябва да наблюдава:

| Интерфейс | Наблюдавани сигнали |
|---|---|
| Instruction input | `instr_i`, `instr_valid_i`, `instr_ready_o` |
| Issue stage | `issue_valid_o`, `issue_opcode_o`, `issue_target_qubit_o`, `issue_control_qubit_o`, `issue_duration_o`, `issue_flags_o` |
| Command stage | `command_valid_o`, `command_opcode_o`, `command_target_qubit_o`, `command_control_qubit_o`, `command_duration_o`, `command_flags_o`, command class outputs |
| Measurement | `measure_request_valid_o`, `measure_qubit_o`, `measurement_busy_o`, result outputs |
| Feedback/branch | `feedback_valid_o`, `branch_taken_o`, `branch_target_o`, `condition_checked_o`, `missing_measurement_o` |
| Status | `scheduler_stall_o`, `illegal_instr_o`, `illegal_issue_o`, `queue_count_o`, `qubit_busy_o` |

Monitor-ът трябва да изпраща observed transactions към scoreboard и coverage чрез analysis ports.

## 3.5.5 Scoreboard

Планиран файл:

```text
uvm/qc_scoreboard.sv
```

Scoreboard-ът трябва да реализира reference модел на очакваното поведение на контролера на instruction ниво. Минималните проверки трябва да включват:

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

---

# 3.6 Test plan

## 3.6.1 Directed tests

Все още няма executable UVM directed tests, защото липсват driver, UVM environment и test top. Вече има реализирани directed sequence класове в `uvm/qc_sequences.sv`, които ще бъдат използвани от бъдещите UVM tests.

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

След добавяне на driver и scoreboard тези sequence класове трябва да бъдат обвити в executable UVM tests, например `qc_smoke_test`, `qc_single_gate_test`, `qc_measure_test`, `qc_branch_test` и `qc_invalid_opcode_test`.

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

---

# 3.9 Ограничения на текущата UVM среда

Текущите ограничения са:

1. Реализирани са UVM package, transaction/sequence item, sequencer и начални sequence класове.
2. Няма driver, monitor, scoreboard, coverage collector, agent, env или executable UVM tests.
3. DUT все още не е свързан към UVM testbench чрез virtual interface.
4. Няма UVM simulation script.
5. Няма потвърден UVM simulator в PATH освен Verilator, който се използва за съществуващите non-UVM RTL testbench-и.
6. Няма UVM logs, UVM waveforms или UVM coverage reports.
7. Constrained-random, stress и algorithmic workloads съществуват като sequence класове, но не са изпълнявани и още нямат scoreboard/coverage резултати.

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
C3: virtual interface и qc_driver.sv
```

Препоръчителен ред:

1. Създаване на SystemVerilog interface за DUT сигналите, например `uvm/qc_if.sv`.
2. Създаване на `uvm/qc_driver.sv`.
3. Driver-ът трябва да извлича `qc_sequence_item` от `qc_sequencer`, да изчаква `instr_ready_o`, да подава `instr_i/instr_valid_i` и да обработва measurement response metadata.
4. Обновяване на `uvm/qc_uvm_pkg.sv`, ако новите класове трябва да бъдат include-нати в package-а.
5. Обновяване на този Markdown файл с реални code excerpts от interface/driver.
6. Обновяване на `docs/AGENT_CONTEXT.md` с новия UVM статус.

Без driver и interface DUT все още не може да бъде управляван от UVM средата, въпреки че sequence stimulus-ът вече е дефиниран.
