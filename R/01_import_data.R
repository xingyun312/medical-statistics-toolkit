# Excel 文件导入模块：只读取原始工作簿，不修改或覆盖文件。

.validate_excel_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(trimws(path))) {
    stop("请提供一个有效的 Excel 文件路径。", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("找不到 Excel 文件：", path, call. = FALSE)
  }
  extension <- tolower(tools::file_ext(path))
  if (!extension %in% c("xlsx", "xls")) {
    stop("仅支持 .xlsx 和 .xls 文件。", call. = FALSE)
  }
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop("缺少 readxl 包。请先在项目 renv 环境中安装依赖。", call. = FALSE)
  }
  invisible(extension)
}

# 返回工作簿的工作表名称，供调用者选择工作表。
list_excel_sheets <- function(path) {
  .validate_excel_path(path)
  tryCatch(
    readxl::excel_sheets(path),
    error = function(error) {
      stop("无法读取 Excel 工作表列表（", path, "）：", conditionMessage(error), call. = FALSE)
    }
  )
}

.resolve_excel_sheet <- function(sheet, sheet_names) {
  if (is.numeric(sheet) && length(sheet) == 1L && !is.na(sheet) &&
      is.finite(sheet) && sheet == floor(sheet) && sheet >= 1) {
    if (sheet > length(sheet_names)) {
      stop("工作表序号超出范围。可用工作表：", paste(sheet_names, collapse = ", "), call. = FALSE)
    }
    return(sheet_names[[as.integer(sheet)]])
  }
  if (is.character(sheet) && length(sheet) == 1L && !is.na(sheet) && nzchar(sheet)) {
    if (!sheet %in% sheet_names) {
      stop("找不到工作表 '" , sheet, "'。可用工作表：", paste(sheet_names, collapse = ", "), call. = FALSE)
    }
    return(sheet)
  }
  stop("sheet 必须是有效的工作表序号或名称。", call. = FALSE)
}

# 支持 .xlsx/.xls；sheet 可传工作表序号或名称。
import_excel <- function(path, sheet = 1) {
  sheet_names <- list_excel_sheets(path)
  selected_sheet <- .resolve_excel_sheet(sheet, sheet_names)
  tryCatch(
    readxl::read_excel(path = path, sheet = selected_sheet, .name_repair = "unique"),
    error = function(error) {
      stop("读取 Excel 文件 '" , path, "' 的工作表 '" , selected_sheet,
           "' 失败：", conditionMessage(error), call. = FALSE)
    }
  )
}

# 一次完成工作表选择、导入和报告生成；变量类型确认由调用者明确提供。
inspect_excel_file <- function(path, sheet = 1, confirmed_types = NULL) {
  sheet_names <- list_excel_sheets(path)
  selected_sheet <- .resolve_excel_sheet(sheet, sheet_names)
  data <- import_excel(path, sheet = selected_sheet)
  report <- generate_data_quality_report(
    data = data,
    source_file = path,
    worksheet = selected_sheet,
    confirmed_types = confirmed_types
  )
  list(
    data = data,
    sheet_names = sheet_names,
    selected_sheet = selected_sheet,
    basic_info = report$basic_info,
    variable_types = report$variable_types,
    quality_report = report
  )
}

