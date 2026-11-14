# 当前已实现模块和 demo 所需的依赖包。
# 仅检查、加载，不负责安装或更新包。
required_packages <- c("readxl", "openxlsx", "renv")

# 后续模块使用时再加入 required_packages，避免提前安装未用到的依赖：
# planned_packages <- c(
#   "dplyr", "tidyr", "janitor", "gtsummary", "rstatix", "ggplot2",
#   "ggpubr", "flextable", "officer", "testthat"
# )

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0L) {
  stop(
    "当前模块缺少依赖包：",
    paste(missing_packages, collapse = ", "),
    "。请使用 renv 安装；本脚本不会自动安装包。",
    call. = FALSE
  )
}

invisible(lapply(required_packages, function(package) {
  suppressPackageStartupMessages(library(package, character.only = TRUE))
}))

message("当前模块依赖检查通过；已加载：", paste(required_packages, collapse = ", "))
