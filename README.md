# Movie-Recommendation-System
Building and Validating a Predictive Rating System Using Neo4j and the MovieLens Dataset

### Academic Project at ENSAI, Rennes.
This project presents the design, implementation, and evaluation of a Movie Recommendation System built using the Neo4j graph database and the MovieLens dataset. It adopts a graph-based architecture to model complex relationships between users, movies, and genres. The system provides predictive ratings by combining two primary approaches: Content-Based Filtering and User-Based Collaborative Filtering.

## Outline
- Exploratory Data Analysis and Graph Structure Exploratio
- Content-Based Approach: The Item Profile Implementation
- Collaborative Filtering: Leveraging User Similarities
- System Validation: Experimenting with a New User
- Synthesis and Insights from the Recommendation System

The system's predictive performance was evaluated using standard metrics (RMSE and MAE) and the Collaborative Filtering model achieved significantly better predictive accuracy, demonstrating its robustness in modeling complex user preferences.

The complete analysis, including all results and findings, is available in the **[Report.pdf](Report.pdf)**, which includes also the full download link for the dataset (`movies.csv` and `ratings.csv`).
All data ingestion, Exploratory Data Analysis and recommendation logic are implemented directly using Cypher queries in **[Query.cypher](Query.cypher)**. The visualizations (charts and plots) are based on the three raw dataset files included in the repository, **[export.csv](export.csv)**, **[export(2).csv](export(2).csv)**, **[export(3).csv](export(3).csv)**, providing insights into user behavior, genre popularity and predictive ratings evaluation, while the code for the plots realization is available in **[Projects_plots.R](Projects_plots.R)**.
