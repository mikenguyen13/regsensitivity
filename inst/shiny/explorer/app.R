## Interactive explorer for a regsensitivity analysis.
##
## Launched by regsen_explore(), which puts the model and data in
## `.regsen_explore_env` rather than passing them through global options,
## so several sessions cannot clobber each other.

env <- get(".regsen_explore_env", envir = asNamespace("regsensitivity"))

ui <- shiny::fluidPage(
    shiny::titlePanel("regsensitivity explorer"),
    shiny::sidebarLayout(
        shiny::sidebarPanel(
            width = 3,
            shiny::radioButtons(
                "analysis", "Analysis",
                choices = c("DMP (2026)" = "dmp", "Oster (2019)" = "oster"),
                selected = "dmp"),

            shiny::conditionalPanel(
                condition = "input.analysis == 'dmp'",
                shiny::sliderInput("cbar", shiny::HTML("c&#772; (control endogeneity)"),
                                   min = 0, max = 1, value = c(0.1, 1), step = 0.05),
                shiny::numericInput("ncbar", "Number of c&#772; values",
                                    value = 3, min = 1, max = 10, step = 1),
                shiny::numericInput("rybar", shiny::HTML("r&#772;<sub>y</sub> (Inf = unrestricted)"),
                                    value = Inf)
            ),
            shiny::conditionalPanel(
                condition = "input.analysis == 'oster'",
                shiny::sliderInput("delta", "delta", min = -5, max = 5,
                                   value = c(-3, 3), step = 0.25)
            ),

            shiny::hr(),
            shiny::selectInput("hyp", "Hypothesis",
                               choices = c("sign change" = "sign",
                                           "beta = 0"    = "eq0")),
            shiny::sliderInput("ywidth", "y-axis half-width (sd of X)",
                               min = 0.5, max = 10, value = 3, step = 0.5),
            shiny::checkboxInput("legend", "Show legend", TRUE),
            shiny::helpText("Bounds that leave the panel are unbounded, ",
                            "not clipped.")
        ),

        shiny::mainPanel(
            width = 9,
            shiny::tabsetPanel(
                shiny::tabPanel("Plot",
                                shiny::plotOutput("plot", height = "460px")),
                shiny::tabPanel("Summary", shiny::verbatimTextOutput("summary")),
                shiny::tabPanel("Table",   shiny::tableOutput("table"))
            )
        )
    )
)

server <- function(input, output, session) {

    result <- shiny::reactive({
        beta <- if (identical(input$hyp, "eq0")) {
            regsensitivity::bnd_eq(0)
        } else {
            "sign"
        }

        args <- list(formula = env$formula, data = env$data,
                     compare = env$compare, beta = beta)

        if (identical(input$analysis, "dmp")) {
            n <- max(1L, as.integer(input$ncbar))
            args$cbar <- seq(input$cbar[1], input$cbar[2], length.out = n)
            if (is.finite(input$rybar)) args$rybar <- input$rybar
        } else {
            args$analysis <- "oster"
            args$delta <- seq(input$delta[1], input$delta[2], length.out = 50)
            args$delta_type <- "eq"
        }

        # A slider combination with no solution should grey the panel, not
        # crash the session.
        tryCatch(do.call(regsensitivity::regsen_bounds, args),
                 error = function(e) e)
    })

    output$plot <- shiny::renderPlot({
        res <- result()
        shiny::validate(shiny::need(!inherits(res, "error"),
                                    paste("No result for these settings:",
                                          conditionMessage(res))))
        plot(res, ywidth = input$ywidth, show_legend = input$legend)
    })

    output$summary <- shiny::renderPrint({
        res <- result()
        if (inherits(res, "error")) cat("Error:", conditionMessage(res), "\n")
        else print(res)
    })

    output$table <- shiny::renderTable({
        res <- result()
        shiny::validate(shiny::need(!inherits(res, "error"), "No result."))
        head(as.data.frame(res, digits = 4), 50)
    })
}

shiny::shinyApp(ui, server)
