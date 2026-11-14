# 仅创建带明确模拟标识的描述统计测试工作簿；不覆盖已有文件。
fixture <- file.path("tests", "fixtures", "simulated_descriptive_data.xlsx")
if (file.exists(fixture)) stop("模拟工作簿已存在，为避免覆盖已停止：", fixture, call. = FALSE)
dir.create(dirname(fixture), recursive = TRUE, showWarnings = FALSE)
simulated_data <- data.frame(
  simulation_flag = rep("SIMULATED_NOT_REAL", 12),
  record_id = sprintf("SIM-%03d", 1:12),
  treatment = c("Control", "Treatment", "Control", "Treatment", "Control", "Treatment", "Control", "Treatment", "Control", "Treatment", NA, "Control"),
  age = c(42, 51, 38, 60, 47, 55, 49, 63, NA, 45, 52, 57),
  bmi = c(21.4, 25.1, 23.6, 29.3, 22.8, 27.5, 24.2, NA, 26.1, 20.9, 28.2, 23.0),
  sex = c("Female", "Male", "Female", "Male", "Female", "Male", "Female", "Male", "Female", "Male", "Female", " "),
  disease_stage = c("I", "II", "II", "III", "I", "III", "II", "II", "I", "III", "II", "I"),
  response = c(1, 0, 1, 1, 0, 1, 0, 1, 0, 1, NA, 0),
  stringsAsFactors = FALSE
)
openxlsx::write.xlsx(simulated_data, fixture, overwrite = FALSE)
message("已创建模拟数据工作簿：", fixture)
