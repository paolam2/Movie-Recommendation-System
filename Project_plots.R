# Plot 1
library(readr)
data <- read_csv("Downloads/export(2).csv")
head(data)

# Create classes with equal intervals: 0-200, 201-400, etc.
data$rating_class <- cut(data$NumRatings, 
                         breaks = seq(0, 2500, by = 200),
                         labels = paste0(seq(0, 2300, by = 200), "-", seq(200, 2500, by = 200)))

# Compute number of users for each class
class_distribution <- as.data.frame(table(data$rating_class))
colnames(class_distribution) <- c("RatingClass", "NumUsers")

# Remove na
class_distribution <- na.omit(class_distribution)

# Create the plot
library(ggplot2)

ggplot(class_distribution, aes(x = RatingClass, y = NumUsers)) +
  geom_bar(stat = "identity", fill = "steelblue", alpha = 0.8) +
  geom_text(aes(label = NumUsers), vjust = -0.5, size = 3) +
  labs(title = "User Distribution by Rating Count Class",
       subtitle = "Classes of 200 ratings each",
       x = "Rating Count Class",
       y = "Number of Users") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

################################################################################

# Plot 2
data <- read_csv("Downloads/export.csv")

# Compute percentages
data$Percentage <- round(data$NumMovies / sum(data$NumMovies) * 100, 1)

# Create the plot
ggplot(data, aes(x = reorder(Genre, NumMovies), y = NumMovies)) +
  geom_bar(stat = "identity", fill = "steelblue", alpha = 0.8) +
  geom_text(aes(label = paste0(NumMovies, " (", Percentage, "%)")), 
            hjust = -0.1, size = 3) +
  labs(title = "Movie Distribution by Genre",
       x = "Genre",
       y = "Number of Movies") +
  coord_flip() +
  theme_minimal() +
  scale_y_continuous(expand = expansion(mult = c(0, 0.2)))  

################################################################################

# Plot 3
dati_cf <- read_csv("Downloads/export(3).csv")

# Create scatterplot
ggplot(dati_cf, aes(x = PredictedRating, y = ConfidenceScore)) +
  geom_point(color = "#0072B2", size = 4) +
  geom_text_repel(aes(label = RecommendedMovie), 
                  box.padding = 0.5,  
                  point.padding = 0.5, 
                  segment.color = 'grey50', 
                  size = 3.5,       
                  max.overlaps = Inf 
  ) +
  labs(title = "User 672: Predicted Rating vs. Confidence Score",
       x = "Predicted Rating",
       y = "Confidence Score") +
  theme_minimal() +
  scale_x_continuous(limits = c(min(dati_cf$PredictedRating) - 0.05, 
                                max(dati_cf$PredictedRating) + 0.05),
                     breaks = unique(round(dati_cf$PredictedRating, 2))) +
  theme(panel.grid.minor = element_blank())

