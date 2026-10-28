
library(shiny)
library(dplyr)
library(readr)
library(ggplot2)

# Load dataset
data <- read_csv("C:\\GitHub-Trending-Analysis-Simplified\\data\\github_trending_repos.csv", show_col_types = FALSE)

# Clean data
data <- data %>%
  select(language, stars, forks, description) %>%
  distinct() %>%
  mutate(
    language = ifelse(is.na(language) | language == "", "Unknown", language),
    description = ifelse(is.na(description), "", description),
    stars = as.numeric(stars),
    forks = as.numeric(forks),
    description_length = nchar(description)
  ) %>%
  filter(!is.na(stars), !is.na(forks), stars >= 0, forks >= 0)

# Define popularity using median stars
star_threshold <- median(data$stars, na.rm = TRUE)

data$popularity <- ifelse(data$stars > star_threshold, 1, 0)

# Group languages with fewer than 10 repositories
language_counts <- table(data$language)

data$language <- ifelse(
  language_counts[data$language] < 10,
  "Other",
  data$language
)

data$language <- factor(data$language)

# Train logistic regression model
set.seed(123)

train_rows <- sample(
  seq_len(nrow(data)),
  size = floor(0.8 * nrow(data))
)

training_data <- data[train_rows, ]

model <- glm(
  popularity ~ forks + language + description_length,
  data = training_data,
  family = binomial()
)

# User interface
ui <- fluidPage(
  titlePanel("GitHub Repository Popularity Prediction"),
  
  sidebarLayout(
    sidebarPanel(
      h4("Enter Repository Characteristics"),
      
      selectInput(
        "language",
        "Programming Language:",
        choices = levels(data$language),
        selected = levels(data$language)[1]
      ),
      
      numericInput(
        "forks",
        "Number of Forks:",
        value = 500,
        min = 0
      ),
      
      numericInput(
        "description_length",
        "Description Length (characters):",
        value = 150,
        min = 0
      ),
      
      actionButton(
        "predict",
        "Estimate Popularity"
      )
    ),
    
    mainPanel(
      h3("Prediction Result"),
      
      textOutput("result"),
      
      h4("Estimated Probability of Popularity"),
      
      textOutput("probability"),
      
      uiOutput("probability_bar"),
      
      hr(),
      
      h4("How to Interpret the Prediction"),
      
      textOutput("explanation"),
      
      hr(),
      
      h4("About the Model"),
      
      textOutput("model_info")
    )
  )
)

# Server
server <- function(input, output) {
  
  prediction <- eventReactive(input$predict, {
    
    req(input$forks >= 0)
    req(input$description_length >= 0)
    
    new_data <- data.frame(
      forks = input$forks,
      language = factor(
        input$language,
        levels = levels(data$language)
      ),
      description_length = input$description_length
    )
    
    probability <- predict(
      model,
      newdata = new_data,
      type = "response"
    )
    
    list(
      probability = as.numeric(probability),
      language = input$language,
      forks = input$forks,
      description_length = input$description_length
    )
  })
  
  output$result <- renderText({
    req(prediction())
    
    if (prediction()$probability >= 0.5) {
      "Popular Repository"
    } else {
      "Not Popular Repository"
    }
  })
  
  output$probability <- renderText({
    req(prediction())
    
    paste0(
      round(prediction()$probability * 100, 2),
      "%"
    )
  })
  
  output$probability_bar <- renderUI({
    req(prediction())
    
    probability <- prediction()$probability * 100
    
    div(
      style = paste0(
        "background-color: #e5e7eb;",
        "width: 100%; height: 28px;",
        "border-radius: 6px; overflow: hidden;"
      ),
      
      div(
        style = paste0(
          "background-color: #2563eb;",
          "width: ", probability, "%;",
          "height: 28px;"
        )
      )
    )
  })
  
  output$explanation <- renderText({
    req(prediction())
    
    p <- prediction()
    
    paste0(
      "The model evaluated a repository using the programming language ",
      p$language,
      ", ",
      p$forks,
      " forks, and a description length of ",
      p$description_length,
      " characters. Based on patterns learned from the training dataset, ",
      "it estimated a ",
      round(p$probability * 100, 2),
      "% probability of belonging to the popular category. ",
      "This is a statistical estimate, not a guarantee of future popularity."
    )
  })
  
  output$model_info <- renderText({
    paste0(
      "Algorithm: Logistic Regression. ",
      "Popularity threshold: more than ",
      format(round(star_threshold), big.mark = ","),
      " stars. ",
      "Classification cutoff: 50% predicted probability. ",
      "The model uses forks, programming language, and description length ",
      "as predictors; stars define the popularity category."
    )
  })
}

shinyApp(ui = ui, server = server)