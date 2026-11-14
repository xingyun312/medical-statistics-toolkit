# 描述性统计结果导出：默认不覆盖现有文件，并拒绝写入原始数据目录。

.validate_export_target <- function(path, extension, overwrite = FALSE) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(trimws(path))) {
    stop("请提供有效的导出路径。", call. = FALSE)
  }
  if (tolower(tools::file_ext(path)) != extension) stop("导出文件扩展名必须为 .", extension, "。", call. = FALSE)
  normalized <- normalizePath(dirname(path), winslash = "/", mustWork = FALSE)
  raw_dir <- normalizePath("data/raw", winslash = "/", mustWork = FALSE)
  if (identical(tolower(normalized), tolower(raw_dir)) || startsWith(tolower(normalized), paste0(tolower(raw_dir), "/"))) {
    stop("统计结果不得导出到 data/raw 原始数据目录。", call. = FALSE)
  }
  if (file.exists(path) && !isTRUE(overwrite)) stop("目标文件已存在；如需覆盖，请显式设置 overwrite = TRUE。", call. = FALSE)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}

export_descriptive_excel <- function(result,
  path = file.path("output", "tables", "descriptive_summary.xlsx"), overwrite = FALSE) {
  if (!inherits(result, "descriptive_summary")) stop("result 必须由 create_descriptive_summary() 生成。", call. = FALSE)
  .validate_export_target(path, "xlsx", overwrite)
  notes <- data.frame(note = c(result$notes,
    paste0("样本量：", result$n_total),
    if (!is.null(result$by)) paste0("分组变量：", result$by) else "未分组"), stringsAsFactors = FALSE)
  sheets <- list(
    "描述性统计" = as.data.frame(result$table_data, check.names = FALSE),
    "缺失数据" = result$missing_summary,
    "分组样本量" = result$group_counts,
    "说明" = notes
  )
  openxlsx::write.xlsx(sheets, file = path, overwrite = overwrite, asTable = FALSE)
  invisible(normalizePath(path, winslash = "/", mustWork = TRUE))
}

export_descriptive_word <- function(result,
  path = file.path("output", "reports", "descriptive_summary.docx"),
  title = "描述性统计表", overwrite = FALSE) {
  if (!inherits(result, "descriptive_summary")) stop("result 必须由 create_descriptive_summary() 生成。", call. = FALSE)
  .validate_export_target(path, "docx", overwrite)
  summary_ft <- gtsummary::as_flex_table(result$table)
  summary_ft <- flextable::theme_booktabs(summary_ft)
  summary_ft <- flextable::autofit(summary_ft)
  missing_ft <- flextable::flextable(result$missing_summary)
  missing_ft <- flextable::theme_booktabs(missing_ft)
  missing_ft <- flextable::autofit(missing_ft)
  doc <- officer::read_docx()
  doc <- officer::body_add_par(doc, title, style = "heading 1")
  doc <- officer::body_add_par(doc, paste0("总样本量：", result$n_total,
    if (!is.null(result$by)) paste0("；分组变量：", result$by) else ""))
  doc <- flextable::body_add_flextable(doc, summary_ft)
  doc <- officer::body_add_par(doc, "缺失数据", style = "heading 2")
  doc <- flextable::body_add_flextable(doc, missing_ft)
  doc <- officer::body_add_par(doc, "分组样本量", style = "heading 2")
  counts_ft <- flextable::autofit(flextable::theme_booktabs(flextable::flextable(result$group_counts)))
  doc <- flextable::body_add_flextable(doc, counts_ft)
  doc <- officer::body_add_par(doc, "说明", style = "heading 2")
  for (note in result$notes) doc <- officer::body_add_par(doc, note)
  print(doc, target = path)
  invisible(normalizePath(path, winslash = "/", mustWork = TRUE))
}
