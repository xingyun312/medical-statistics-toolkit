# Excel 导入和数据质量报告验证；所有医学风格数据均为模拟数据。
source(file.path("R", "01_import_data.R"))
source(file.path("R", "02_data_quality.R"))

sample_path <- file.path("tests", "fixtures", "simulated_quality_checks.xlsx")
stopifnot(file.exists(sample_path))
file_hash_before <- unname(tools::md5sum(sample_path))
sheets <- list_excel_sheets(sample_path)
stopifnot(identical(sheets, c("SIMULATED_ONLY", "SIMULATED_ALTERNATE")))

confirmed_types <- c(
  synthetic_flag = "text",
  patient_code = "identifier",
  group = "categorical",
  age = "continuous",
  sex = "categorical",
  empty_column = "other",
  crp_mg_l = "continuous"
)
inspection <- inspect_excel_file(sample_path, sheet = "SIMULATED_ONLY",
                                 confirmed_types = confirmed_types)
imported_by_index <- import_excel(sample_path, sheet = 1)
alternate_inspection <- inspect_excel_file(sample_path, sheet = 2)
report <- inspection$quality_report

stopifnot(nrow(inspection$data) == 13L)
stopifnot(inspection$basic_info$n_rows == 13L)
stopifnot(inspection$basic_info$n_columns == 7L)
stopifnot(identical(inspection$basic_info$variable_names, names(inspection$data)))
stopifnot(identical(inspection$data, imported_by_index))
stopifnot(all(inspection$data$synthetic_flag == "SIMULATED_ONLY"))
stopifnot(inspection$selected_sheet == "SIMULATED_ONLY")
stopifnot(alternate_inspection$selected_sheet == "SIMULATED_ALTERNATE")
stopifnot(nrow(alternate_inspection$data) == 3L)
stopifnot(all(alternate_inspection$data$group == "Alternate simulated sheet"))
stopifnot(report$source_file == sample_path && report$worksheet == "SIMULATED_ONLY")
stopifnot(report$missing_summary$missing_n[report$missing_summary$variable == "age"] == 1L)
stopifnot(report$duplicate_record_count == 1L)
stopifnot(identical(report$duplicate_rows, c(4L, 13L)))
stopifnot("empty_column" %in% report$empty_columns)
stopifnot(any(report$outliers$variable == "crp_mg_l" & report$outliers$value == 100))
stopifnot(any(report$issues$check == "缺失值"))
stopifnot(any(report$issues$check == "空列"))
stopifnot(any(report$issues$check == "重复记录"))
stopifnot(any(report$issues$check == "数值异常值提示"))
stopifnot(all(report$variable_types$confirmation_status == "人工已确认"))
stopifnot(all(report$variable_types$confirmed_type == unname(confirmed_types)))
stopifnot(identical(unname(tools::md5sum(sample_path)), file_hash_before))

# 未提供人工映射时，自动识别只给建议并标记待确认。
pending_types <- identify_variable_types(inspection$data)
stopifnot(all(pending_types$confirmation_status == "待人工确认"))
stopifnot(grepl("需确认", pending_types$suggested_type[pending_types$variable == "age"]))

# 非有限数值单独报告；原始值保留。
non_finite_report <- check_data_quality(data.frame(value = c(1, 2, 3, 4, Inf)))
stopifnot(nrow(non_finite_report$non_finite_values) == 1L)
stopifnot(is.infinite(non_finite_report$non_finite_values$value[[1]]))

# 明确的输入错误提示。
stopifnot(inherits(try(import_excel("README.md"), silent = TRUE), "try-error"))
stopifnot(inherits(try(import_excel(sample_path, sheet = "NO_SUCH_SHEET"), silent = TRUE), "try-error"))
stopifnot(inherits(try(identify_variable_types(inspection$data,
  confirmed_types = c(not_a_variable = "text")), silent = TRUE), "try-error"))

# 用 readxl 自带的非临床测试工作簿单独验证旧版 .xls 格式读取。
xls_fixture <- system.file("extdata", "clippy.xls", package = "readxl")
if (nzchar(xls_fixture) && file.exists(xls_fixture)) {
  xls_sheets <- list_excel_sheets(xls_fixture)
  stopifnot(length(xls_sheets) > 0L)
  xls_data <- import_excel(xls_fixture, sheet = 1)
  stopifnot(is.data.frame(xls_data), ncol(xls_data) > 0L)
} else {
  stop("readxl 包未提供 .xls 测试样例，无法验证旧版 Excel 格式。", call. = FALSE)
}

cat("Excel 导入与数据质量报告验证通过。\n")
cat(".xlsx 模拟数据：", report$n_rows, "行 × ", report$n_columns,
    "列；缺失年龄 1 个；重复记录副本 1 条；空列 1 列；CRP 异常值提示 1 个。\n", sep = "")
cat(".xls 格式样例：成功读取工作表 ", xls_sheets[[1]], "。\n", sep = "")
print(report)


