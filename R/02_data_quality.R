# 数据质量检查与报告：只提示问题，不删除记录、不填补缺失值、不改写输入数据。

.confirmed_variable_types <- function(data, confirmed_types = NULL) {
  allowed_types <- c("continuous", "categorical", "binary", "date", "datetime",
                     "text", "identifier", "logical", "other")
  if (is.null(confirmed_types)) return(setNames(character(), character()))
  if (!is.character(confirmed_types) || is.null(names(confirmed_types)) ||
      anyNA(confirmed_types) || any(!nzchar(names(confirmed_types)))) {
    stop("confirmed_types 必须是以变量名命名的字符向量。", call. = FALSE)
  }
  if (anyDuplicated(names(confirmed_types))) {
    stop("confirmed_types 中的变量名不能重复。", call. = FALSE)
  }
  unknown_variables <- setdiff(names(confirmed_types), names(data))
  if (length(unknown_variables)) {
    stop("类型确认中包含不存在的变量：", paste(unknown_variables, collapse = ", "), call. = FALSE)
  }
  invalid_types <- setdiff(unname(confirmed_types), allowed_types)
  if (length(invalid_types)) {
    stop("不支持的确认类型：", paste(unique(invalid_types), collapse = ", "),
         "。允许类型：", paste(allowed_types, collapse = ", "), call. = FALSE)
  }
  confirmed_types
}

# 只根据 R 存储类型提出建议；数值变量的临床含义必须由用户确认。
identify_variable_types <- function(data, confirmed_types = NULL) {
  if (!is.data.frame(data)) stop("data 必须是 data.frame 或 tibble。", call. = FALSE)
  confirmed_types <- .confirmed_variable_types(data, confirmed_types)

  rows <- lapply(names(data), function(variable) {
    values <- data[[variable]]
    storage_type <- paste(class(values), collapse = "/")
    suggested_type <- if (inherits(values, "POSIXt")) {
      "日期时间候选"
    } else if (inherits(values, "Date")) {
      "日期候选"
    } else if (is.logical(values)) {
      "二分类候选"
    } else if (is.numeric(values)) {
      "数值（需确认连续变量或数值编码分类变量）"
    } else if (is.character(values) || is.factor(values)) {
      "文本/分类候选（需确认变量含义）"
    } else {
      "其他类型（需人工确认）"
    }
    is_confirmed <- variable %in% names(confirmed_types)
    data.frame(
      variable = variable,
      storage_type = storage_type,
      suggested_type = suggested_type,
      confirmed_type = if (is_confirmed) unname(confirmed_types[[variable]]) else NA_character_,
      confirmation_status = if (is_confirmed) "人工已确认" else "待人工确认",
      stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) {
    return(data.frame(variable = character(), storage_type = character(),
                      suggested_type = character(), confirmed_type = character(),
                      confirmation_status = character(), stringsAsFactors = FALSE))
  }
  do.call(rbind, rows)
}

get_data_basic_info <- function(data) {
  if (!is.data.frame(data)) stop("data 必须是 data.frame 或 tibble。", call. = FALSE)
  list(
    n_rows = nrow(data),
    n_columns = ncol(data),
    variable_names = names(data)
  )
}

.missing_mask <- function(values) {
  missing <- is.na(values)
  if (is.character(values) || is.factor(values)) {
    text <- as.character(values)
    missing <- missing | (!is.na(text) & !nzchar(trimws(text)))
  }
  missing
}

.empty_issue_table <- function() {
  data.frame(check = character(), severity = character(), variable = character(),
             details = character(), stringsAsFactors = FALSE)
}

# 返回结构化质量报告；数值异常采用 1.5×IQR 提示规则，不作为自动删值依据。
check_data_quality <- function(data, confirmed_types = NULL) {
  if (!is.data.frame(data)) stop("data 必须是 data.frame 或 tibble。", call. = FALSE)
  if (ncol(data) == 0L) stop("数据没有任何变量列。", call. = FALSE)

  type_review <- identify_variable_types(data, confirmed_types)
  missing_rows <- lapply(names(data), function(variable) {
    missing_n <- sum(.missing_mask(data[[variable]]))
    data.frame(
      variable = variable,
      missing_n = missing_n,
      missing_percent = if (nrow(data)) 100 * missing_n / nrow(data) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  missing_summary <- do.call(rbind, missing_rows)

  variable_rows <- lapply(names(data), function(variable) {
    values <- data[[variable]]
    is_numeric <- is.numeric(values)
    finite_values <- if (is_numeric) values[is.finite(values)] else numeric()
    type_row <- type_review[type_review$variable == variable, , drop = FALSE]
    levels_text <- if (is.factor(values) || is.character(values) || is.logical(values) ||
                       isTRUE(type_row$confirmed_type %in% c("categorical", "binary"))) {
      observed <- values[! .missing_mask(values)]
      levels <- unique(as.character(observed))
      paste(utils::head(levels, 20L), collapse = "; ")
    } else {
      NA_character_
    }
    data.frame(
      type_row,
      missing_n = missing_summary$missing_n[missing_summary$variable == variable],
      missing_percent = missing_summary$missing_percent[missing_summary$variable == variable],
      levels = levels_text,
      numeric_min = if (length(finite_values)) min(finite_values) else NA_real_,
      numeric_max = if (length(finite_values)) max(finite_values) else NA_real_,
      non_finite_n = if (is_numeric) sum(is.infinite(values), na.rm = TRUE) else 0L,
      empty_column = nrow(data) > 0L && all(.missing_mask(values)),
      stringsAsFactors = FALSE
    )
  })
  variable_summary <- do.call(rbind, variable_rows)

  duplicate_rows <- which(duplicated(data) | duplicated(data, fromLast = TRUE))
  duplicate_record_count <- sum(duplicated(data))
  empty_columns <- variable_summary$variable[variable_summary$empty_column]

  non_finite_rows <- lapply(names(data)[vapply(data, is.numeric, logical(1))], function(variable) {
    rows <- which(is.infinite(data[[variable]]))
    if (!length(rows)) return(NULL)
    data.frame(variable = variable, row = rows, value = data[[variable]][rows],
               stringsAsFactors = FALSE)
  })
  non_finite_rows <- Filter(Negate(is.null), non_finite_rows)
  non_finite_values <- if (length(non_finite_rows)) do.call(rbind, non_finite_rows) else
    data.frame(variable = character(), row = integer(), value = numeric(), stringsAsFactors = FALSE)

  outlier_rows <- lapply(names(data)[vapply(data, is.numeric, logical(1))], function(variable) {
    values <- data[[variable]]
    finite_rows <- which(is.finite(values))
    observed <- values[finite_rows]
    if (length(observed) < 4L) return(NULL)
    quartiles <- stats::quantile(observed, probs = c(0.25, 0.75), names = FALSE, type = 7)
    spread <- quartiles[[2L]] - quartiles[[1L]]
    lower <- quartiles[[1L]] - 1.5 * spread
    upper <- quartiles[[2L]] + 1.5 * spread
    local_rows <- which(observed < lower | observed > upper)
    if (!length(local_rows)) return(NULL)
    rows <- finite_rows[local_rows]
    data.frame(variable = variable, row = rows, value = values[rows],
               lower_fence = lower, upper_fence = upper, stringsAsFactors = FALSE)
  })
  outlier_rows <- Filter(Negate(is.null), outlier_rows)
  outliers <- if (length(outlier_rows)) do.call(rbind, outlier_rows) else
    data.frame(variable = character(), row = integer(), value = numeric(),
               lower_fence = numeric(), upper_fence = numeric(), stringsAsFactors = FALSE)

  issues <- .empty_issue_table()
  add_issue <- function(check, severity, variable, details) {
    issues <<- rbind(issues, data.frame(check = check, severity = severity,
      variable = variable, details = details, stringsAsFactors = FALSE))
  }
  if (nrow(data) == 0L) add_issue("空数据集", "警告", "", "工作表没有数据行。")
  for (i in which(missing_summary$missing_n > 0L)) {
    add_issue("缺失值", "提示", missing_summary$variable[[i]],
      sprintf("%d 个（%.2f%%）", missing_summary$missing_n[[i]], missing_summary$missing_percent[[i]]))
  }
  if (length(empty_columns)) add_issue("空列", "警告", paste(empty_columns, collapse = ", "), "整列为空或仅含空白字符。")
  if (duplicate_record_count > 0L) add_issue("重复记录", "警告", "",
    sprintf("%d 条重复副本；涉及数据行：%s。", duplicate_record_count, paste(duplicate_rows, collapse = ", ")))
  if (nrow(non_finite_values)) add_issue("非有限数值", "警告", paste(unique(non_finite_values$variable), collapse = ", "),
    sprintf("发现 %d 个 Inf/-Inf 值。", nrow(non_finite_values)))
  if (nrow(outliers)) add_issue("数值异常值提示", "复核", paste(unique(outliers$variable), collapse = ", "),
    sprintf("按 1.5×IQR 规则发现 %d 个候选异常值。", nrow(outliers)))
  pending <- type_review$variable[type_review$confirmation_status == "待人工确认"]
  if (length(pending)) add_issue("变量类型待确认", "提示", paste(pending, collapse = ", "),
    "请结合变量含义确认变量类型；存储类型不能确定临床变量含义。")

  structure(list(
    source_file = NULL,
    worksheet = NULL,
    n_rows = nrow(data),
    n_columns = ncol(data),
    variable_names = names(data),
    basic_info = get_data_basic_info(data),
    variable_types = type_review,
    variable_summary = variable_summary,
    missing_summary = missing_summary,
    duplicate_record_count = duplicate_record_count,
    duplicate_rows = duplicate_rows,
    empty_columns = empty_columns,
    non_finite_values = non_finite_values,
    outliers = outliers,
    issues = issues,
    outlier_method = "Tukey 1.5×IQR；仅提示人工复核，不自动删除。"
  ), class = "data_quality_report")
}

# 添加 Excel 来源信息并生成可打印的完整报告对象。
generate_data_quality_report <- function(data, source_file = NULL, worksheet = NULL,
                                          confirmed_types = NULL) {
  report <- check_data_quality(data, confirmed_types = confirmed_types)
  report$source_file <- source_file
  report$worksheet <- worksheet
  report
}

print.data_quality_report <- function(x, ...) {
  cat("数据质量检查报告\n")
  if (!is.null(x$source_file)) cat("文件：", x$source_file, "\n", sep = "")
  if (!is.null(x$worksheet)) cat("工作表：", x$worksheet, "\n", sep = "")
  cat("数据规模：", x$n_rows, " 行 × ", x$n_columns, " 列\n", sep = "")
  cat("变量：", paste(x$variable_names, collapse = ", "), "\n", sep = "")
  cat("缺失值：", sum(x$missing_summary$missing_n), " 个；重复记录副本：",
      x$duplicate_record_count, " 条；空列：", length(x$empty_columns),
      " 列；非有限数值：", nrow(x$non_finite_values),
      " 个；异常值提示：", nrow(x$outliers), " 个。\n", sep = "")
  pending <- sum(x$variable_types$confirmation_status == "待人工确认")
  cat("变量类型待人工确认：", pending, " 个。\n", sep = "")
  if (nrow(x$issues)) print(x$issues, row.names = FALSE)
  cat("异常值规则：", x$outlier_method, "\n", sep = "")
  invisible(x)
}

