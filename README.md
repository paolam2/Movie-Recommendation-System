# Movie-Recommendation-System
Building and Validating a Predictive Rating System Using Neo4j and the MovieLens Dataset

### Academic Project at ENSAI, Rennes.
This project presents the design, implementation, and evaluation of a Movie Recommendation System built using the Neo4j graph database and the MovieLens dataset. It adopts a graph-based architecture to model complex relationships between users, movies, and genres. The system provides predictive ratings by combining two primary approaches: Content-Based Filtering and User-Based Collaborative Filtering.

## Outline
- Exploratory Data Analysis and Graph Structure Exploration
- Content-Based Approach: The Item Profile Implementation
- Collaborative Filtering: Leveraging User Similarities
- System Validation: Experimenting with a New User
- Synthesis and Insights from the Recommendation System

The system's predictive performance was evaluated using standard metrics (RMSE and MAE) and the Collaborative Filtering model achieved significantly better predictive accuracy, demonstrating its robustness in modeling complex user preferences.

## Repository Structure & Tools
The complete analysis, including all results and findings, is available in the **[Report.pdf](Report.pdf)**, which also includes the full download link for the primary dataset (`movies.csv` and `ratings.csv`).
- **[Query.cypher](Query.cypher)**: All data ingestion, Exploratory Data Analysis, and recommendation logic (Cypher / Neo4j).
- **[Projects_plots.R](Projects_plots.R)**: Code used for the visualizations (plots) (R Language).|
- **[export.csv](export.csv)**, **[export(2).csv](export(2).csv)**, **[export(3).csv](export(3).csv)**: Raw data files used to generate the R-based charts and analysis plots. 
