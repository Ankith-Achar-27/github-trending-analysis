
# ============================================================
# PROJECT: What Makes a GitHub Repository Popular?
# EDA + LOGISTIC REGRESSION
# ============================================================

library(ggplot2)
library(dplyr)
library(readr)

# 1. Load dataset
data <- read_csv(
  "C:/GitHub-Trending-Analysis-Simplified/data/github_trending_repos.csv",
  show_col_types = FALSE
)

# 2. Preprocess data
data <- data %>%
  select(full_name, language, stars, forks, description, timeframe) %>%
  distinct(full_name, timeframe, .keep_all = TRUE) %>%
  mutate(
    stars = as.numeric(stars),
    forks = as.numeric(forks),
    language = ifelse(is.na(language) | language == "", "Unknown", language),
    description = ifelse(is.na(description), "", description),
    description_length = nchar(description)
  ) %>%
  filter(
    is.finite(stars),
    is.finite(forks),
    stars >= 0,
    forks >= 0
  )

# 3. Define popularity
star_threshold <- median(data$stars)

data <- data %>%
  mutate(
    popularity = ifelse(stars > star_threshold, 1, 0)
  )

cat("Total repositories:", nrow(data), "\n")
cat("Median star threshold:", star_threshold, "\n")
cat("1 = Popular; 0 = Not Popular\n")
print(table(data$popularity))

# 4. Correlation analysis
cat("\nCorrelation between forks and stars:\n")
print(cor(data$forks, data$stars))

cat("\nCorrelation between description length and stars:\n")
print(cor(data$description_length, data$stars))

# 5. Exploratory Data Analysis

# Repository count by language
data %>%
  count(language, sort = TRUE) %>%
  slice_head(n = 10) %>%
  ggplot(aes(x = reorder(language, n), y = n)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Top Programming Languages",
    x = "Language",
    y = "Repository Count"
  ) +
  theme_minimal()

# Distribution of stars
ggplot(data, aes(x = stars)) +
  geom_histogram(bins = 30) +
  scale_x_log10(labels = scales::comma) +
  labs(
    title = "Distribution of Repository Stars",
    x = "Number of Stars (Log Scale)",
    y = "Repository Count"
  ) +
  theme_minimal()

# Relationship between forks and stars
ggplot(data, aes(x = forks, y = stars)) +
  geom_point(alpha = 0.6) +
  scale_x_continuous(labels = scales::comma) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Stars vs Forks",
    x = "Number of Forks",
    y = "Number of Stars"
  ) +
  theme_minimal()

# Popularity by language
data %>%
  group_by(language) %>%
  summarise(
    popular_percent = mean(popularity) * 100,
    count = n(),
    .groups = "drop"
  ) %>%
  filter(count >= 5) %>%
  arrange(desc(popular_percent)) %>%
  slice_head(n = 10) %>%
  print()


# 6. Prepare data for logistic regression
model_data <- data %>%
  select(popularity, forks, language, description_length)

# Combine infrequent languages
language_counts <- table(model_data$language)
rare_languages <- names(language_counts[language_counts < 10])

model_data$language <- as.character(model_data$language)

model_data$language[
  model_data$language %in% rare_languages
] <- "Other"

model_data$language <- factor(model_data$language)

# 7. Split data into training and testing sets
set.seed(123)

train_rows <- sample(
  seq_len(nrow(model_data)),
  size = floor(0.8 * nrow(model_data))
)

training_data <- model_data[train_rows, ]
testing_data <- model_data[-train_rows, ]

# Handle language categories not observed in training
training_languages <- unique(as.character(training_data$language))

testing_data$language <- as.character(testing_data$language)

testing_data$language[
  !testing_data$language %in% training_languages
] <- "Other"

# Ensure Other is available in training if needed
if (!"Other" %in% training_languages &&
    any(testing_data$language == "Other")) {
  testing_data$language[
    testing_data$language == "Other"
  ] <- training_languages[1]
}

training_data$language <- factor(training_data$language)

testing_data$language <- factor(
  testing_data$language,
  levels = levels(training_data$language)
)

# 8. Compare models with and without description length

# Model with description length
model_full <- glm(
  popularity ~ forks + language + description_length,
  data = training_data,
  family = binomial()
)

# Model without description length
model_simple <- glm(
  popularity ~ forks + language,
  data = training_data,
  family = binomial()
)

# Predict on the same test dataset
pred_full <- predict(
  model_full,
  newdata = testing_data,
  type = "response"
)

pred_simple <- predict(
  model_simple,
  newdata = testing_data,
  type = "response"
)

# Convert probabilities into categories
actual <- testing_data$popularity

class_full <- ifelse(pred_full >= 0.5, 1, 0)
class_simple <- ifelse(pred_simple >= 0.5, 1, 0)

# Compare accuracy
accuracy_full <- mean(class_full == actual)
accuracy_simple <- mean(class_simple == actual)

cat("\nMODEL COMPARISON\n")

cat(
  "Accuracy with description length:",
  round(accuracy_full * 100, 2), "%\n"
)

cat(
  "Accuracy without description length:",
  round(accuracy_simple * 100, 2), "%\n"
)

# 9. Final logistic regression model
model <- model_full

cat("\nLOGISTIC REGRESSION RESULTS\n")
print(summary(model))

# 10. Evaluate the final model
probability <- predict(
  model,
  newdata = testing_data,
  type = "response"
)

predicted <- ifelse(probability >= 0.5, 1, 0)

cat("\nCONFUSION MATRIX\n")

print(table(
  Actual = actual,
  Predicted = predicted
))


# Calculate evaluation metrics
TP <- sum(actual == 1 & predicted == 1)
TN <- sum(actual == 0 & predicted == 0)
FP <- sum(actual == 0 & predicted == 1)
FN <- sum(actual == 1 & predicted == 0)

accuracy <- (TP + TN) / (TP + TN + FP + FN)
precision <- TP / (TP + FP)
recall <- TP / (TP + FN)
f1_score <- 2 * precision * recall / (precision + recall)

cat("Accuracy:", round(accuracy * 100, 2), "%\n")
cat("Precision:", round(precision * 100, 2), "%\n")
cat("Recall:", round(recall * 100, 2), "%\n")
cat("F1-Score:", round(f1_score * 100, 2), "%\n")


cat("\nAnalysis completed!\n")
