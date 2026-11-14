# Medical Statistics Toolkit

基于 R 的医学科研统计分析工具项目，按阶段实现 Excel 数据导入、质量检查及后续统计分析。本阶段只提供导入与质量检查，不含描述性统计、统计检验或绘图。

## 本阶段功能

- 支持 `.xlsx` 和 `.xls`，可通过工作表序号或名称选择工作表。
- 展示记录数、变量数和变量名。
- 根据 R 存储类型提出变量类型建议；变量含义由用户通过 `confirmed_types` 映射人工确认，未确认的变量会标为待确认。
- 检查缺失值及比例、重复记录、全空列、数值范围、`Inf/-Inf` 和 1.5×IQR 候选异常值。
- 以结构化 `data_quality_report` 对象生成报告，也可 `print()` 输出摘要。
- 检查只报告问题，不删除记录、不填补缺失值、不修改输入数据。

## 目录结构

- `data/raw/`：用户原始 Excel 数据；脚本仅读取，不覆盖，默认不纳入 Git。
- `data/processed/`：后续阶段保存的处理数据。
- `R/00_packages.R`：检查并加载当前功能所需的 `readxl`、`openxlsx`、`renv`。
- `R/01_import_data.R`：工作表列表、Excel 导入和组合检查入口。
- `R/02_data_quality.R`：基本信息、变量类型建议/确认、质量检查和报告。
- `config/analysis_config.R`：后续分析配置框架。
- `tests/fixtures/simulated_quality_checks.xlsx`：带缺失值、重复记录、空列和候选异常值的模拟工作簿。
- `tests/create_simulated_data.R`：只在目标文件不存在时创建模拟工作簿，不覆盖已有文件。
- `tests/verify_import_quality.R`：本阶段模拟数据验证脚本，并使用 readxl 自带非临床 `.xls` 样例检查旧格式读取。
- `output/tables/`、`output/figures/`、`output/reports/`：后续导出目录。
- `renv/`、`renv.lock`：项目依赖管理配置和锁文件。

## 运行验证

Windows 上可用完整路径启动 R，无需修改 PATH：

```powershell
$rs = 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe'
& $rs -e 'source("R/00_packages.R"); source("tests/verify_import_quality.R")'
```

预期输出包含 `Excel 导入与数据质量报告验证通过。`。模拟工作簿应读出 13 行、7 列，检查到 1 个年龄缺失值、1 条重复副本、1 个全空列和 1 个 CRP 候选异常值。原始模拟工作簿的校验值在检查前后保持一致。

## 在自己的工作簿上检查

在项目根目录运行 R 后，可按工作表名称读取，并显式确认需要的变量类型：

```r
source("R/00_packages.R")
source("R/01_import_data.R")
source("R/02_data_quality.R")

inspection <- inspect_excel_file(
  path = "data/raw/example.xlsx",
  sheet = "Sheet1",
  confirmed_types = c(
    age = "continuous",
    group = "categorical",
    patient_code = "identifier"
  )
)

inspection$basic_info
inspection$variable_types
print(inspection$quality_report)
```

可确认的类型为 `continuous`、`categorical`、`binary`、`date`、`datetime`、`text`、`identifier`、`logical`、`other`。传入映射只确认其中列出的变量；其余变量保留“待人工确认”。检查建议和异常值提示需要结合研究设计与变量含义复核。

## 数据安全

示例数据全部为模拟数据。不要将真实患者身份信息发送到外部服务。原始工作簿放入 `data/raw/`，`.gitignore` 默认排除原始 Excel 文件；仅保留明确标记的模拟 fixture。
