# 描述性统计：使用 gtsummary 生成汇总表，不执行假设检验。

.as_variable_type_map <- function(data, variable_types) {
  if (is.data.frame(variable_types)) {
    if (!all(c("variable", "confirmed_type") %in% names(variable_types))) {
      stop("variable_types 数据框需包含 variable 和 confirmed_type 列。", call. = FALSE)
    }
    confirmed <- variable_types$confirmed_type
    names(confirmed) <- variable_types$variable
    variable_types <- confirmed
  }
  if (!is.character(variable_types) || is.null(names(variable_types)) || anyDuplicated(names(variable_types))) {
    stop("variable_types 必须是按变量名命名的字符向量或类型确认表。", call. = FALSE)
  }
  allowed <- c("continuous", "categorical", "binary", "date", "datetime", "text", "identifier", "logical", "other")
  invalid <- setdiff(unname(variable_types), allowed)
  if (length(invalid)) stop("variable_types 中存在不支持的类型：", paste(unique(invalid), collapse = ", "), call. = FALSE)
  if (any(!names(data) %in% names(variable_types)) || anyNA(variable_types[names(data)])) {
    stop("请先人工确认数据中每个变量的类型。", call. = FALSE)
  }
  variable_types[names(data)]
}

.summary_formula <- function(variable, rhs) {
  lhs <- paste(deparse(as.name(variable), backtick = TRUE), collapse = "")
  rhs_text <- if (is.character(rhs) && length(rhs) == 1L) {
    encodeString(rhs, quote = "\"")
  } else if (is.character(rhs)) {
    paste0("c(", paste(vapply(rhs, encodeString, character(1), quote = "\""), collapse = ", "), ")")
  } else {
    paste0("c(", paste(as.character(rhs), collapse = ", "), ")")
  }
  stats::as.formula(paste(lhs, "~", rhs_text), env = parent.frame())
}

.normalize_missing_text <- function(x) {
  if (is.character(x) || is.factor(x)) {
    value <- as.character(x)
    value[!is.na(value) & !nzchar(trimws(value))] <- NA_character_
    return(value)
  }
  x
}

.make_missing_summary <- function(data, variables, group_values = NULL, group_name = NULL) {
  groups <- list(Overall = seq_len(nrow(data)))
  if (!is.null(group_values)) groups <- c(groups,
    split(seq_len(nrow(data)), factor(group_values, levels = unique(group_values)), drop = FALSE))
  rows <- list()
  for (variable in variables) {
    missing <- .missing_mask(.normalize_missing_text(data[[variable]]))
    for (group in names(groups)) {
      idx <- groups[[group]]
      n_total <- length(idx)
      n_missing <- sum(missing[idx])
      rows[[length(rows) + 1L]] <- data.frame(
        variable = variable, group = group, n_total = n_total,
        n_nonmissing = n_total - n_missing, missing_n = n_missing,
        missing_percent = if (n_total) 100 * n_missing / n_total else NA_real_,
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) return(data.frame(variable=character(), group=character(), n_total=integer(), n_nonmissing=integer(), missing_n=integer(), missing_percent=numeric()))
  do.call(rbind, rows)
}

# variable_types 必须来自研究者的人工确认；variables 控制进入主表的变量。
create_descriptive_summary <- function(data, variable_types, by = NULL,
                                       variables = NULL) {
  if (!is.data.frame(data) || ncol(data) == 0L) stop("data 必须是包含变量列的数据框。", call. = FALSE)
  if (anyDuplicated(names(data)) || any(!nzchar(names(data)))) stop("数据列名必须非空且唯一。", call. = FALSE)
  type_map <- .as_variable_type_map(data, variable_types)
  eligible <- names(type_map)[type_map %in% c("continuous", "categorical", "binary")]
  if (!is.null(by)) {
    if (length(by) != 1L || !by %in% names(data)) stop("by 必须是数据中单个分组变量名。", call. = FALSE)
    if (!type_map[[by]] %in% c("categorical", "binary")) stop("分组变量必须人工确认类型为 categorical 或 binary。", call. = FALSE)
    eligible <- setdiff(eligible, by)
  }
  if (is.null(variables)) variables <- eligible
  if (!is.character(variables) || !length(variables) || anyDuplicated(variables) || any(!variables %in% eligible)) {
    stop("variables 只能包含已确认的连续或分类变量。", call. = FALSE)
  }
  continuous <- variables[type_map[variables] == "continuous"]
  if (length(continuous) && any(!vapply(data[continuous], is.numeric, logical(1)))) {
    stop("已确认为连续变量的列必须为数值型；请先复核导入与变量类型。", call. = FALSE)
  }
  if (length(continuous) && any(vapply(data[continuous], function(x) any(is.infinite(x), na.rm=TRUE), logical(1)))) {
    stop("连续变量包含 Inf/-Inf。请先复核数据质量报告，不会自动删除这些值。", call. = FALSE)
  }
  work <- data
  for (variable in names(work)) work[[variable]] <- .normalize_missing_text(work[[variable]])
  categorical <- variables[type_map[variables] %in% c("categorical", "binary")]
  for (variable in categorical) work[[variable]] <- factor(work[[variable]])
  groups <- NULL
  if (!is.null(by)) {
    group <- as.character(work[[by]])
    missing_group <- is.na(group)
    missing_label <- "缺失分组"
    while (missing_label %in% group) missing_label <- paste0(missing_label, "*")
    group[missing_group] <- missing_label
    work[[by]] <- factor(group, levels = unique(group))
    groups <- group
  }

  summary_types <- c(setNames(rep("continuous2", length(continuous)), continuous),
                     setNames(rep("categorical", length(categorical)), categorical))
  type_formulas <- lapply(names(summary_types), function(v) .summary_formula(v, summary_types[[v]]))
  statistic_formulas <- c(
    lapply(continuous, function(v) .summary_formula(v, c("{mean} ± {sd}", "{median} ({p25}, {p75})", "{min}, {max}"))),
    lapply(categorical, function(v) .summary_formula(v, "{n} ({p}%)"))
  )
  table <- gtsummary::tbl_summary(
    data = work,
    by = if (is.null(by)) NULL else tidyselect::all_of(by),
    include = tidyselect::all_of(variables), type = type_formulas,
    statistic = statistic_formulas,
    missing = "no", percent = "column"
  )
  if (!is.null(by)) table <- gtsummary::add_overall(table, last = TRUE)
  group_counts <- if (is.null(by)) {
    data.frame(group = "Overall", n = nrow(data), stringsAsFactors = FALSE)
  } else {
    as.data.frame(table(groups), stringsAsFactors = FALSE)
  }
  if (!is.null(by)) names(group_counts) <- c("group", "n")
  missing_summary <- .make_missing_summary(data, names(data), groups)
  structure(list(
    table = table, table_data = gtsummary::as_tibble(table, col_labels = TRUE),
    missing_summary = missing_summary, group_counts = group_counts,
    variables = variables, variable_types = type_map, by = by,
    n_total = nrow(data), notes = c("连续变量：均值 ± 标准差、中位数（Q1，Q3）、最小值和最大值。",
      "分类变量：频数及列百分比；缺失值另表统计。", "未执行组间假设检验，不包含 P 值。")
  ), class = "descriptive_summary")
}

print.descriptive_summary <- function(x, ...) {
  cat("描述性统计表：", x$n_total, " 条记录；变量：", paste(x$variables, collapse = ", "), "\n", sep = "")
  if (!is.null(x$by)) cat("分组变量：", x$by, "\n", sep = "")
  print(x$table)
  invisible(x)
}
