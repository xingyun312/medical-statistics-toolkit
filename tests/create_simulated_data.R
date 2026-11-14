# 生成明确标记为模拟数据的 Excel 示例。不会覆盖已有文件。

if (!requireNamespace("openxlsx", quietly = TRUE)) {
  stop("生成模拟 Excel 文件需要 openxlsx。", call. = FALSE)
}

output_path <- file.path("tests", "fixtures", "simulated_quality_checks.xlsx")
if (file.exists(output_path)) {
  stop("示例文件已存在，为避免覆盖已停止：", output_path, call. = FALSE)
}

simulated <- data.frame(
  synthetic_flag = rep("SIMULATED_ONLY", 12),
  patient_code = sprintf("SIM%03d", 1:12),
  group = rep(c("Control", "Treatment"), each = 6),
  age = c(34, 41, 52, 46, 39, NA, 37, 44, 50, 48, 55, 42),
  sex = c("F", "M", "F", "F", "M", "M", "M", "F", "F", "M", "F", "M"),
  empty_column = rep(NA_character_, 12),
  crp_mg_l = c(2.1, 3.2, 4.0, 3.5, 2.8, 3.1, 1.9, 2.4, 3.0, 2.6, 100, 2.2),
  stringsAsFactors = FALSE
)
# 故意加入一条完全重复记录，用于演示质量检查提示。
simulated <- rbind(simulated, simulated[4, , drop = FALSE])
alternate <- simulated[1:3, , drop = FALSE]
alternate$group <- "Alternate simulated sheet"

openxlsx::write.xlsx(
  x = list(SIMULATED_ONLY = simulated, SIMULATED_ALTERNATE = alternate),
  file = output_path,
  overwrite = FALSE,
  asTable = TRUE
)
message("已生成模拟示例数据：", output_path)
