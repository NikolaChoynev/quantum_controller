# AGENT_CONTEXT.md

## 1. Общ контекст на проекта

Този проект е част от дисертационен труд, свързан с разработване на **instruction-driven RTL архитектура на класически контролер за управление на квантови операции**.

Основната идея на проекта е да се реализира цифров контролен слой, който приема абстрактни квантови инструкции, декодира ги, буферира ги, анализира зависимостите между операциите, планира изпълнението им и генерира цифрови управляващи команди към абстрактен quantum execution layer.

Проектът не реализира физически квантов процесор, не моделира аналогови импулси, не моделира шум, декохерентност или конкретна хардуерна квантова технология. Фокусът е върху цифровата RTL архитектура на контролера, нейното симулационно тестване, бъдеща UVM верификация и начална оценка чрез synthesis flow.

---

## 2. Основна тема на дисертацията

Работната тема е:

**Разработване на RTL архитектура на контролер за квантови изчисления и неговата верификация**

Контролерът е:

- instruction-driven;
- реализиран на SystemVerilog RTL ниво;
- тестван чрез Verilator testbench-и;
- подготвен за бъдеща UVM верификационна среда;
- подготвен за начална Yosys-friendly synthesis проверка чрез отделен synthesis top.

---

## 3. Основна структура на дисертацията

Дисертационният труд следва следната структура:

```text
УВОД
ГЛАВА 1 – Теоретични основи и анализ на съществуващи решения
ГЛАВА 2 – RTL архитектура на квантовия контролер
ГЛАВА 3 – UVM базирана верификационна среда
ГЛАВА 4 – Експериментален анализ и синтез
ЗАКЛЮЧЕНИЕ
ПРИЛОЖЕНИЯ
БИБЛИОГРАФИЯ
```

Към момента Глава 1 е разписана в голяма степен. Добавен е подраздел:

```text
1.2.6 Алгоритмично мотивирани и benchmark натоварвания
```

Този раздел използва Bell, GHZ, Grover-like, measurement-feedback и random-circuit-sampling-inspired сценарии като мотивация за бъдещи UVM и експериментални workloads.

Важно: Google Sycamore и Willow се използват само като мотивационни примери. Не трябва да се твърди, че проектът възпроизвежда Google хардуерен експеримент.

---

## 4. Основно правило за писане

Проектът следва **implementation-first** подход.

Това означава:

- първо се реализира код;
- след това кодът се тества;
- след това се записва в Git;
- едва след това се описва в дисертацията като реализиран резултат.

Не трябва да се описва като завършено нещо, което още не е реализирано, тествано и commit-нато.

Бъдещи идеи трябва да бъдат описвани като:

- ограничение на текущата реализация;
- възможно бъдещо разширение;
- следващ етап от проекта.

### 4.1 Правило за поддръжка на AGENT_CONTEXT.md

При всяка съществена нова промяна, корекция или напредък по проекта агентът трябва да прецени дали има информация, която е полезна за бъдещ контекст. Ако има такава информация, `docs/AGENT_CONTEXT.md` трябва да бъде обновен в същия работен цикъл.

Като подходяща информация се считат:

- нови RTL модули или съществени промени в поведението им;
- нови testbench-и, regression резултати или synthesis резултати;
- промени в архитектурни решения, ограничения или работния план;
- нов потвърден commit, който променя реалния статус на проекта;
- важни бележки за това какво вече е реализирано и какво все още не трябва да се твърди като завършено в дисертацията.

Не трябва да се добавя шумна временна информация, непотвърдени идеи или подробни дневници от всяка команда. Файлът трябва да остане кратък, стабилен и полезен за следващ агент.

---

## 5. Текущ RTL статус

Базовата RTL фаза е завършена.

Реализирани RTL модули:

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

Реализирани testbench-и:

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

Основният regression script е:

```text
scripts/run_verilator.sh
```

Последният потвърден важен RTL/control commit е:

```text
502415c Fix control scheduling hazards
```

Този commit означава, че освен интегрираната feedback логика са потвърдени и следните control-flow корекции:

- `OP_WAIT` вече задържа scheduler-а за зададената `duration`;
- `MEASURE` операциите имат backpressure и не се издава второ измерване, докато първото е pending;
- `BRANCH` се третира като in-flight операция до получаване на feedback резултат;
- при taken branch `operation_queue` се flush-ва, така че по-млади queued инструкции да не се изпълнят погрешно;
- `rtl_synth/quantum_controller_top_synth.sv` е синхронизиран с това поведение.

Потвърдено е чрез:

```text
./scripts/run_verilator.sh all
./scripts/run_yosys_synth.sh
```

Yosys flow-ът минава с очаквани memory-to-register предупреждения за вътрешни масиви.

---

## 6. Реализиран RTL pipeline

Към момента реализираният top-level поток е:

```text
raw 32-bit instruction
→ instruction_decoder
→ operation_queue
→ scheduler
→ execution_controller
→ measurement_controller
→ feedback_unit
→ output command / measurement / branch signals
```

По-подробно:

1. `instruction_decoder.sv` приема 32-битова инструкция и извлича `opcode`, `target_qubit`, `control_qubit`, `duration`, `flags` и illegal status.
2. `operation_queue.sv` буферира валидни декодирани инструкции.
3. `operation_queue.sv` поддържа flush при taken branch.
4. `dependency_tracker.sv` проверява дали дадена операция използва заети кубити.
5. `scheduler.sv` издава операция само ако няма dependency hazard, downstream stage-ът е готов и няма активен WAIT hold.
6. `execution_controller.sv` преобразува issued операцията в цифров command интерфейс.
7. `measurement_controller.sv` обработва MEASURE команди, генерира measurement request и съхранява резултати.
8. `feedback_unit.sv` обработва BRANCH/feedback сценарии на база съхранени measurement резултати.
9. `quantum_controller_top.sv` интегрира всички основни модули и добавя top-level backpressure за MEASURE/BRANCH control-flow сценарии.

---

## 7. Важни RTL ограничения

Текущата реализация има следните ограничения:

- Scheduler-ът е in-order dependency-aware scheduler.
- Не е реализиран пълен out-of-order DAG scheduler.
- Няма реален физически quantum backend.
- Няма аналогов pulse generator.
- `execution_controller.sv` генерира цифрови command сигнали, не реални pulse waveforms.
- Measurement резултатите се подават абстрактно чрез входни сигнали.
- Feedback логиката работи върху съхранени measurement резултати.
- Yosys synthesis не се прави директно върху целия основен модулен SystemVerilog RTL, а чрез отделен synthesis-friendly top.

Тези ограничения трябва да бъдат ясно описани в Глава 2 и Глава 4.

---

## 8. Synthesis статус

Основният RTL в директорията `rtl/` се използва за:

- Verilator симулации;
- бъдеща UVM верификация;
- академично описание на архитектурата.

Поради ограниченията на наличната Yosys инсталация:

- няма `read_slang`;
- няма `sv2v`;
- стандартният Yosys SystemVerilog frontend има затруднения с `package`, `typedef` и `struct` конструкции;

е създаден отделен synthesis-friendly top:

```text
rtl_synth/quantum_controller_top_synth.sv
```

Yosys flow файлове:

```text
scripts/synth_quantum_controller_top.ys
scripts/run_yosys_synth.sh
```

Generated synthesis reports:

```text
results/synthesis_reports/quantum_controller_top_synth_yosys.log
results/synthesis_reports/quantum_controller_top_synth.json
```

Важно правило за писане:

Не трябва да се твърди, че оригиналният модулен RTL в `rtl/` е директно синтезиран от Yosys, докато това не бъде реално постигнато. Трябва ясно да се пише, че първият synthesis smoke test е извършен чрез `rtl_synth/quantum_controller_top_synth.sv`.

---

## 9. Обновена структура на Глава 2

Глава 2 трябва да следва тази структура:

```text
2.1 Архитектурна концепция
2.1.1 Системни изисквания
2.1.2 Дефиниране на instruction format
2.1.3 Обхват, допускания и ограничения на RTL реализацията
2.1.4 Общ архитектурен модел

2.2 Организация на RTL проекта и файловата структура
2.2.1 Директории и роля на основните файлове
2.2.2 Общ package и параметри на архитектурата (qc_pkg.sv)
2.2.3 Тестова и simulation инфраструктура
2.2.4 Synthesis-friendly RTL вариант

2.3 Блокова архитектура на контролера
2.3.1 Top-level архитектура
2.3.2 Основни RTL модули
2.3.3 Поток на данни
2.3.4 Контролен поток
2.3.5 Интерфейси и изходни сигнали

2.4 Математическа формализация на scheduler
2.4.1 Моделиране на квантова операция
2.4.2 Представяне чрез dependency graph / DAG
2.4.3 Ресурсни ограничения и qubit busy модел
2.4.4 Критерий за latency и stall cycles
2.4.5 Реализиран dependency-aware scheduling алгоритъм
2.4.6 Анализ на сложността и ограничения на текущата реализация

2.5 RTL имплементация на основните модули
2.5.1 Instruction package и instruction format (qc_pkg.sv)
2.5.2 Instruction Decoder (instruction_decoder.sv)
2.5.3 Operation Queue (operation_queue.sv)
2.5.4 Dependency Tracker (dependency_tracker.sv)
2.5.5 Scheduler (scheduler.sv)
2.5.6 Execution Controller и цифров command интерфейс (execution_controller.sv)
2.5.7 Measurement Controller (measurement_controller.sv)
2.5.8 Feedback Unit (feedback_unit.sv)
2.5.9 Top-level интеграция (quantum_controller_top.sv)

2.6 FSM и вътрешни контролни състояния
2.6.1 Queue и scheduler поведение
2.6.2 Busy-counter модел за кубити
2.6.3 Measurement pending logic
2.6.4 Feedback/branch decision logic

2.7 Pipeline архитектура и end-to-end изпълнение
2.7.1 Път на инструкцията през контролера
2.7.2 Gate/measure/wait/reset/branch командни сценарии
2.7.3 End-to-end MEASURE → result → BRANCH сценарий
2.7.4 Ограничения на текущия in-order pipeline

2.8 Verilator симулационна проверка на RTL
2.8.1 Module-level testbench-и
2.8.2 Top-level integration testbench
2.8.3 Regression script и simulation logs
2.8.4 Waveform файлове и проследимост към RTL

2.9 Синтезируемост и Yosys-friendly synthesis flow
2.9.1 Синтезируем SystemVerilog subset
2.9.2 Причина за отделен rtl_synth вариант
2.9.3 quantum_controller_top_synth.sv
2.9.4 Yosys scripts и synthesis reports
2.9.5 Ограничения и бъдещо подобрение на synthesis flow

2.10 Обобщение на реализираната RTL архитектура
2.10.1 Проследимост между изисквания, модули и тестове
2.10.2 Ограничения на текущата реализация
2.10.3 Подготовка за UVM верификация
```

Старите точки `Pulse Generator` и `Memory Subsystem` не трябва да се използват като реализирани модули, защото не съществуват като такива в текущия RTL.

---

## 10. Как трябва да се пише Глава 2

Глава 2 трябва да бъде написана като описание на вече реализирана архитектура.

Правилен стил:

```text
В реализирания RTL модел instruction decoder модулът извлича opcode, target_qubit, control_qubit, duration и flags от 32-битовата инструкция.
```

Неправилен стил:

```text
Ще бъде разработен instruction decoder, който ще извлича opcode...
```

Препоръчително е в текста да има препратки към реални файлове:

```text
Реализацията на instruction format-а е централизирана в `rtl/qc_pkg.sv`.
Поведението на decoder модула се проверява чрез `tb/tb_instruction_decoder.sv`.
```

---

## 11. Следваща непосредствена задача

Следващата задача е писане и преработка на Глава 2.

Препоръчителна последователност:

1. Преработване на вече написаните 2.1, 2.1.1 и 2.1.2.
2. Писане на 2.1.3.
3. Писане на 2.1.4.
4. Продължаване с 2.2–2.10.
5. Добавяне на таблици:
   - requirements → RTL modules → tests;
   - RTL files → dissertation sections;
   - module → testbench → simulation log.
6. Добавяне на диаграми:
   - top-level block diagram;
   - instruction pipeline diagram;
   - scheduler/dependency flow;
   - measurement-feedback flow.
7. След завършване на Глава 2 се преминава към UVM разработка и Глава 3.

---

## 12. Бележки за бъдещ агент/Codex

Когато този проект се отвори в Codex, VS Code или друг AI агент, първо трябва да се прочетат:

```text
docs/AGENT_CONTEXT.md
docs/chapter_2_rtl_architecture.md
docs/Работен План.docx
docs/Структура на дисертационен труд.docx
docs/Дисертация.docx
```

След това агентът трябва да провери реалния код в:

```text
rtl/
tb/
scripts/
rtl_synth/
```

Не трябва да се правят промени по RTL файлове без пускане на:

```bash
./scripts/run_verilator.sh all
```

Промени по synthesis flow трябва да се проверяват чрез:

```bash
./scripts/run_yosys_synth.sh
```
