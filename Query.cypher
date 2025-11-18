// EXPLORATORY DATA ANALYSSIS (EDA) AND GRAPH STRUCTURE EXPLORATION

// Load data
CREATE CONSTRAINT FOR (m:Movie) REQUIRE m.id IS UNIQUE;
CREATE CONSTRAINT FOR (u:User) REQUIRE u.id IS UNIQUE;

LOAD CSV WITH HEADERS FROM "file:///movies.csv" AS line WITH line,
SPLIT(line.genres, "|") AS Genres CREATE (m:Movie { id:
TOINTEGER(line.`movieId`), title: line.`title` }) WITH Genres, m UNWIND
RANGE(0, SIZE(Genres)-1) as i MERGE (g:Genre {name: toUpper(Genres[i])})
CREATE (m)-[r:HAS_GENRE {position:i+1}]->(g);

LOAD CSV WITH HEADERS FROM "file:///ratings.csv" AS line WITH line MATCH
(m:Movie { id: TOINTEGER(line.`movieId`) }) MERGE (u:User { id:
TOINTEGER(line.`userId`) }) CREATE (u)-[r:RATED
{rating:TOFLOAT(line.`rating`)}]->(m);

// schema
CALL db.schema.visualization()

// Most rated movies
MATCH (m:Movie)<-[r:RATED]-(:User)
RETURN m.title AS Movie, count(r) AS NumRatings
ORDER BY NumRatings DESC
LIMIT 10;

// Most Active Users Analysis
MATCH (u:User)-[r:RATED]->(:Movie)
RETURN u.id AS UserID, count(r) AS NumRatings
ORDER BY NumRatings DESC
LIMIT 10;
// Users for the plot
MATCH (u:User)-[r:RATED]->(:Movie)
RETURN u.id AS UserID, count(r) AS NumRatings
ORDER BY NumRatings DESC;

// Average ratings Analysis
MATCH (u:User)-[r:RATED]->(m:Movie)
RETURN m.title AS Movie, 
       round(avg(r.rating), 2) AS AvgRating, 
       count(r) AS NumRatings
ORDER BY AvgRating DESC, NumRatings DESC
LIMIT 10;

MATCH (:User)-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
RETURN g.name AS Genre, 
       round(avg(r.rating), 2) AS AvgRating, 
       count(r) AS NumRatings
ORDER BY AvgRating DESC;

// Analysis of Highly Rated and Popular Movies
MATCH (u:User)-[r:RATED]->(m:Movie)
WITH m, avg(r.rating) AS AvgRating, count(r) AS NumRatings
WHERE NumRatings > 50
RETURN m.title AS Movie, round(AvgRating,2) AS AvgRating, NumRatings
ORDER BY AvgRating DESC, NumRatings DESC
LIMIT 10;


//Analysis of Movie Distribution by Genre
MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)
RETURN g.name AS Genre, count(m) AS NumMovies
ORDER BY NumMovies DESC;


// CONTENT-BASED APPROACH: THE ITEM PROFILE IMPLEMENTATION

:param title => "Fargo (1996)";
:param limit => 10;

// Jaccard similarity computation

// Find the target movie and collect its genres
MATCH (m1:Movie {title: $title})-[:HAS_GENRE]->(g:Genre)
WITH m1, COLLECT(DISTINCT g.name) AS g1, SIZE(COLLECT(DISTINCT g.name)) AS n1

//Find all other movies and their genres for comparison
MATCH (m2:Movie)-[:HAS_GENRE]->(g2:Genre)
WHERE m2 <> m1
WITH m1, m2, g1, n1, COLLECT(DISTINCT g2.name) AS g2list, SIZE(COLLECT(DISTINCT g2.name)) AS n2

// Calculate Jaccard similarity components
WITH m2,
     SIZE([x IN g1 WHERE x IN g2list]) AS inter,
     (n1 + n2 - SIZE([x IN g1 WHERE x IN g2list])) AS unionSize
// // Filter out cases where union size is zero
WHERE unionSize > 0

// Return results with similarity scoring
RETURN m2.id AS movieId, m2.title AS title,
       inter AS commonGenres,
       // jaccard = inter/unionSize
       toFloat(inter)/toFloat(unionSize) AS jaccard 
ORDER BY jaccard DESC, commonGenres DESC, title
LIMIT $limit;

// predicted rating for movieId = 2 by User = 1
:param userId => 1;
:param movieId => 2;

CALL {
  MATCH (target:Movie {id: $movieId})-[:HAS_GENRE]->(g:Genre)
  WITH target, COLLECT(DISTINCT g.name) AS targetGenres, SIZE(COLLECT(DISTINCT g.name)) AS targetCount

  MATCH (u:User {id: $userId})-[ur:RATED]->(other:Movie)
  WHERE other.id <> $movieId
  MATCH (other)-[:HAS_GENRE]->(og:Genre)
  WITH target, targetGenres, targetCount, ur.rating AS userRating,
       COLLECT(DISTINCT og.name) AS otherGenres, SIZE(COLLECT(DISTINCT og.name)) AS otherCount

  WITH
    SUM( ( toFloat(SIZE([x IN targetGenres WHERE x IN otherGenres])) 
          / toFloat(targetCount + otherCount - SIZE([x IN targetGenres WHERE x IN otherGenres])) )
         * userRating ) AS weightedSum,
    SUM( toFloat(SIZE([x IN targetGenres WHERE x IN otherGenres])) 
         / toFloat(targetCount + otherCount - SIZE([x IN targetGenres WHERE x IN otherGenres])) ) AS totalWeight

  RETURN CASE WHEN totalWeight IS NULL OR totalWeight = 0 THEN NULL ELSE weightedSum / totalWeight END AS predicted,
         coalesce(totalWeight, 0) AS total_weight
}

// fallback if predicted is NULL
WITH predicted, total_weight
OPTIONAL MATCH (u:User {id: $userId})-[ur:RATED]->()
WITH predicted, total_weight, AVG(ur.rating) AS user_avg
OPTIONAL MATCH ()-[mr:RATED]->(m:Movie {id: $movieId})
WITH predicted, total_weight, user_avg, AVG(mr.rating) AS movie_avg
OPTIONAL MATCH ()-[gr:RATED]->()
WITH predicted, total_weight, user_avg, movie_avg, AVG(gr.rating) AS global_avg

RETURN COALESCE(predicted, user_avg, movie_avg, global_avg, 3.0) AS predicted_rating,
       total_weight;

// Content-based evaluation
// Select a test set with 1000 real ratings
MATCH (u:User)-[r:RATED]->(m:Movie)
WITH u, m, r.rating AS real_rating
LIMIT 1000 

// predicted_ratings computation
CALL {
    WITH u, m
    // Lista dei generi del film target
    MATCH (target:Movie {id: m.id})-[:HAS_GENRE]->(g:Genre)
    WITH target, COLLECT(DISTINCT g.name) AS targetGenres, SIZE(COLLECT(DISTINCT g.name)) AS targetCount

    MATCH (u)-[ur:RATED]->(other:Movie)
    WHERE other.id <> target.id
    MATCH (other)-[:HAS_GENRE]->(og:Genre)
    WITH target, targetGenres, targetCount, ur.rating AS userRating, COLLECT(DISTINCT og.name) AS otherGenres, SIZE(COLLECT(DISTINCT og.name)) AS otherCount

    WITH SUM( (toFloat(SIZE([x IN targetGenres WHERE x IN otherGenres])) / toFloat(targetCount + otherCount - SIZE([x IN targetGenres WHERE x IN otherGenres]))) * userRating ) AS weightedSum,
         SUM( toFloat(SIZE([x IN targetGenres WHERE x IN otherGenres])) / toFloat(targetCount + otherCount - SIZE([x IN targetGenres WHERE x IN otherGenres])) ) AS totalWeight

    RETURN CASE WHEN totalWeight = 0 THEN NULL ELSE weightedSum / totalWeight END AS predicted_rating
}

// Fallback if predicted_rating is null
WITH u, m, real_rating, predicted_rating
OPTIONAL MATCH (u)-[ur:RATED]->()
WITH u, m, real_rating, predicted_rating, AVG(ur.rating) AS user_avg
OPTIONAL MATCH ()-[mr:RATED]->(m)
WITH u, m, real_rating, predicted_rating, user_avg, AVG(mr.rating) AS movie_avg
OPTIONAL MATCH ()-[gr:RATED]->()
WITH u, m, real_rating, predicted_rating, user_avg, movie_avg, AVG(gr.rating) AS global_avg

WITH u, m, real_rating,
     COALESCE(predicted_rating, user_avg, movie_avg, global_avg, 3.0) AS final_pred

// RMSE and MAE computation on test set
WITH collect({real: real_rating, pred: final_pred}) AS results
UNWIND results AS r
WITH r.real AS real, r.pred AS pred
RETURN sqrt(AVG((real - pred)*(real - pred))) AS RMSE,
       AVG(ABS(real - pred)) AS MAE;

// Top-10 recommendations for User = 1
:param userId => 1;
:param limit => 10;

// Retrieve movies already rated by the user and their associated genres
MATCH (u:User {id: $userId})-[r:RATED]->(m1:Movie)-[:HAS_GENRE]->(g:Genre)
WITH u, r.rating AS userRating, m1,
     COLLECT(DISTINCT g.name) AS g1,
     SIZE(COLLECT(DISTINCT g.name)) AS n1

// Select all movies that have not yet been rated by the user
MATCH (m2:Movie)-[:HAS_GENRE]->(g2:Genre)
WHERE NOT EXISTS((u)-[:RATED]->(m2)) AND m2 <> m1
WITH m2, g1, n1, COLLECT(DISTINCT g2.name) AS g2list,
     SIZE(COLLECT(DISTINCT g2.name)) AS n2, userRating

// Compute the Jaccard similarity between genres of rated movies and candidate movies
WITH m2, userRating,
     SIZE([x IN g1 WHERE x IN g2list]) AS inter,
     (n1 + n2 - SIZE([x IN g1 WHERE x IN g2list])) AS unionSize
WHERE inter > 0
WITH m2,
     // Weighted sum using squared similarity as weight
     SUM((toFloat(inter) / toFloat(unionSize))^2 * userRating) AS weightedSum,
     // Total weight (sum of squared similarities)
     SUM((toFloat(inter) / toFloat(unionSize))^2) AS weights

// Compute the predicted rating as the weighted average of similar movies' ratings
WITH m2,
     CASE
         WHEN weights = 0 THEN NULL
         ELSE weightedSum / weights
     END AS predictedRating,
     weights AS total_weight

// Normalize the predicted rating between 1 and 5 and return top recommendations
RETURN
     m2.id AS movieId,
     m2.title AS RecommendedMovie,
     CASE
         WHEN predictedRating > 5 THEN 5
         WHEN predictedRating < 1 THEN 1
         ELSE ROUND(predictedRating, 2)
     END AS predictedRating,
     total_weight
ORDER BY predictedRating DESC, RecommendedMovie
LIMIT $limit;

// Number of rated movies by User 1
MATCH (u:User {id: $userId$})-[r:RATED]->(m:Movie)
RETURN u.id AS UserID, count(r) AS TotalRatings;


// COLLABORATIVE FILTERING: LEVERAGING USER SIMILARITIES

// Parameter definition
:param userId => 1;
:param sampleSize => 1000;
:param topN => 30;

// Step 1
MATCH (u:User)-[r:RATED]->(m:Movie)
WITH u, m, r.rating AS actual_rating, rand() AS random
ORDER BY random
LIMIT $sampleSize

// Step 2, 3, 4
MATCH (u)-[r1:RATED]->(common:Movie)<-[r2:RATED]-(u2:User)
WHERE u <> u2
WITH u, m, u2, actual_rating,
     collect(toFloat(r1.rating)) AS v1,
     collect(toFloat(r2.rating)) AS v2
WHERE size(v1) > 1
WITH u, m, u2, actual_rating,
     reduce(dot = 0.0, i IN range(0, size(v1)-1) | dot + (v1[i]*v2[i])) AS dotProduct,
     sqrt(reduce(s = 0.0, x IN v1 | s + (x*x))) AS norm1,
     sqrt(reduce(s = 0.0, x IN v2 | s + (x*x))) AS norm2
WITH u, m, u2, actual_rating,
     CASE WHEN norm1=0 OR norm2=0 THEN 0 ELSE dotProduct/(norm1*norm2) END AS similarity
ORDER BY similarity DESC
WITH u, m, collect({u2: u2, sim: similarity})[..30] AS neighbors, actual_rating
UNWIND neighbors AS n
WITH u, m, n.u2 AS neighbor, n.sim AS sim, actual_rating
MATCH (neighbor)-[r:RATED]->()
WITH u, m, neighbor, sim, actual_rating, avg(toFloat(r.rating)) AS meanNeighbor
MATCH (u)-[rU:RATED]->()
WITH u, m, neighbor, sim, meanNeighbor, avg(toFloat(rU.rating)) AS meanUser, actual_rating
MATCH (neighbor)-[r3:RATED]->(m)
WITH u, m, actual_rating, meanUser,
     sum(sim * (toFloat(r3.rating) - meanNeighbor)) AS weightedSum,
     sum(abs(sim)) AS simSum
WITH u, m, actual_rating,
     CASE 
         WHEN simSum = 0 THEN null
         ELSE meanUser + (weightedSum / simSum)
     END AS raw_predicted
WITH u, m, actual_rating,
     CASE
         WHEN raw_predicted IS NULL THEN NULL
         WHEN raw_predicted < 1 THEN 1
         WHEN raw_predicted > 5 THEN 5
         ELSE raw_predicted
     END AS predicted_rating
     // Compute user averages
MATCH (u)-[rU:RATED]->()
WITH u, avg(toFloat(rU.rating)) AS user_avg, m, predicted_rating, actual_rating

// Compute movie averages
MATCH (m)<-[rM:RATED]-()
WITH u, m, user_avg, avg(toFloat(rM.rating)) AS movie_avg, predicted_rating, actual_rating

// Compute global average
MATCH (:User)-[rG:RATED]->()
WITH u, m, user_avg, movie_avg, avg(toFloat(rG.rating)) AS global_avg, predicted_rating, actual_rating

// Combine all (predicted, user, movie, global)
WITH u, m, actual_rating,
     coalesce(predicted_rating, user_avg, movie_avg, global_avg, 3.0) AS final_pred
     WITH collect({real: actual_rating, pred: final_pred}) AS results
UNWIND results AS r
WITH sqrt(avg((r.pred - r.real)^2)) AS RMSE,
     avg(abs(r.pred - r.real)) AS MAE
RETURN 
    round(RMSE,3) AS RMSE,
    round(MAE,3)  AS MAE;
    
// Step 5
//  Find similar users (neighbors)
MATCH (u:User {id: $userId})-[r1:RATED]->(common:Movie)<-[r2:RATED]-(u2:User)
WHERE u <> u2
WITH u, u2,
     collect(toFloat(r1.rating)) AS v1,
     collect(toFloat(r2.rating)) AS v2
WHERE size(v1) > 1

//  Compute cosine similarity
WITH u, u2,
     reduce(dot = 0.0, i IN range(0, size(v1)-1) | dot + (v1[i]*v2[i])) AS dotProduct,
     sqrt(reduce(s = 0.0, x IN v1 | s + (x*x))) AS norm1,
     sqrt(reduce(s = 0.0, x IN v2 | s + (x*x))) AS norm2
WITH u, u2,
     CASE WHEN norm1=0 OR norm2=0 THEN 0 ELSE dotProduct/(norm1*norm2) END AS similarity
ORDER BY similarity DESC
LIMIT 30

//  Compute mean ratings for target user and neighbors
MATCH (u)-[rU:RATED]->()
WITH u, avg(toFloat(rU.rating)) AS meanUser, collect({u2:u2, sim:similarity}) AS sims

// Predict ratings for movies not yet rated by the user
UNWIND sims AS s
WITH u, meanUser, s.u2 AS neighbor, s.sim AS sim
MATCH (neighbor)-[r3:RATED]->(rec:Movie)
WHERE NOT (u)-[:RATED]->(rec)
WITH rec, meanUser, 
     sum(sim) AS sumSim, 
     sum(sim * (toFloat(r3.rating) - meanUser)) AS weightedSum

//  Normalize and attenuate weights 
WITH rec, meanUser, weightedSum, sumSim,
     (1 - exp(-sumSim / 20.0)) AS attenuation,
     sumSim AS confidence

//  Compute raw predicted rating and blend with global average
MATCH (:User)-[rAll:RATED]->()
WITH rec, meanUser, weightedSum, sumSim, attenuation, confidence,
     avg(toFloat(rAll.rating)) AS global_avg
WITH rec, confidence,
     CASE 
         WHEN sumSim = 0 THEN NULL
         ELSE (
             // 70 % user-based prediction + 30 % global average
             0.7 * (meanUser + ((weightedSum / sumSim) * attenuation)) + 0.3 * global_avg
         )
     END AS raw_predicted

// Clamp final predicted rating to [1, 5]
WITH rec, confidence,
     CASE
         WHEN raw_predicted IS NULL THEN NULL
         WHEN raw_predicted < 1 THEN 1
         WHEN raw_predicted > 5 THEN 5
         ELSE raw_predicted
     END AS PredictedRating

RETURN 
    rec.title AS RecommendedMovie,
    round(PredictedRating, 2) AS PredictedRating,
    round(confidence, 3) AS ConfidenceScore
ORDER BY PredictedRating DESC, ConfidenceScore DESC
LIMIT $topN;


// SYSTEM VALIDATION: EXPERIMENTING WITH A NEW USER

// Add a new user
// Step 1
CREATE(u:User {id:672})
RETURN u;

// Step 2
// MATCH (u:User {id:672})
MATCH (m:Movie)
WHERE m.title IN [
    "Forrest Gump (1994)",
    "Toy Story (1995)",
    "Life in a Day (2011)",
    "Pulp Fiction (1994)",
    "Jurassic Park (1993)",
    "The Godfather (1972)",
    "Groundhog Day (1993)",
    "Saw (2004)",
    "Mean Girls (2004)",
    "Catwoman (2004)",
    "The Room (2003)",
    "Battlefield Earth (2000)",
    "Gigli (2003)",
    "Jack and Jill (2011)"
]
WITH u, m,
CASE m.title
    WHEN "Forrest Gump (1994)" THEN 4
    WHEN "Toy Story (1995)" THEN 4
    WHEN "Life in a Day (2011)" THEN 3
    WHEN "Pulp Fiction (1994)" THEN 5
    WHEN "Jurassic Park (1993)" THEN 5
    WHEN "The Godfather (1972)" THEN 4
    WHEN "Groundhog Day (1993)" THEN 2
    WHEN "Saw (2004)" THEN 1
    WHEN "Mean Girls (2004)" THEN 2
    WHEN "Catwoman (2004)" THEN 1
    WHEN "The Room (2003)" THEN 1
    WHEN "Battlefield Earth (2000)" THEN 2
    WHEN "Gigli (2003)" THEN 1
    WHEN "Jack and Jill (2011)" THEN 2
END AS rating
MERGE (u)-[:RATED {rating: rating}]->(m);

// Step 3
// Retrieve movies already rated by the user and their associated genres
MATCH (u:User {id: 672})-[r:RATED]->(m1:Movie)
MATCH (m1)-[:HAS_GENRE]->(g:Genre)
WITH u, r.rating AS userRating, m1,
     COLLECT(DISTINCT g.name) AS g1,
     SIZE(COLLECT(DISTINCT g.name)) AS n1

// Select all movies that have not yet been rated by the user
MATCH (m2:Movie)-[:HAS_GENRE]->(g2:Genre)
WHERE NOT EXISTS((u)-[:RATED]->(m2)) AND m2 <> m1
WITH m2, g1, n1, COLLECT(DISTINCT g2.name) AS g2list,
     SIZE(COLLECT(DISTINCT g2.name)) AS n2, userRating

// Compute the Jaccard similarity between genres of rated movies and candidate movies
WITH m2, userRating,
     SIZE([x IN g1 WHERE x IN g2list]) AS inter,
     (n1 + n2 - SIZE([x IN g1 WHERE x IN g2list])) AS unionSize
WHERE inter > 0
WITH m2,
     // Weighted sum using squared similarity as weight
     SUM((toFloat(inter) / toFloat(unionSize))^2 * userRating) AS weightedSum,
     // Total weight (sum of squared similarities)
     SUM((toFloat(inter) / toFloat(unionSize))^2) AS weights

// Compute the predicted rating as the weighted average of similar movies' ratings
WITH m2,
     CASE
         WHEN weights = 0 THEN NULL
         ELSE weightedSum / weights
     END AS predictedRating

// Save as property in Movie
SET m2.predictedCB = predictedCB

// Normalize the predicted rating between 1 and 5 and return top recommendations
RETURN
     m2.id AS movieId,
     m2.title AS RecommendedMovie,
     CASE
         WHEN predictedRating > 5 THEN 5
         WHEN predictedRating < 1 THEN 1
         ELSE ROUND(predictedRating, 2)
     END AS predictedRating
ORDER BY predictedRating DESC, RecommendedMovie
LIMIT 10;

// Step 4
// Cosine Similarity for 672

// Find user 672 and all the other users who rated the same movie as 672
MATCH (u1:User {id: 672})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE u1 <> u2
// For each pair (u1, u2) collect their ratings on the same movies
WITH u1, u2,
     collect(toFloat(r1.rating)) AS v1,
     collect(toFloat(r2.rating)) AS v2
// Consider only pairs with at least 3 common movies
WHERE size(v1) > 2
// Compute cosine similarity between the two rating vectors
WITH u1, u2,
     reduce(dot = 0.0, i IN range(0, size(v1)-1) | dot + (v1[i]*v2[i])) AS dotProduct,
     sqrt(reduce(s = 0.0, x IN v1 | s + x^2)) AS norm1,
     sqrt(reduce(s = 0.0, x IN v2 | s + x^2)) AS norm2
// Cosine similarity: dotProduct / (norm1 * norm2)
WITH u1, u2,
     CASE WHEN norm1 = 0 OR norm2 = 0 THEN 0 ELSE dotProduct/(norm1*norm2) END AS similarity
// Filter by significant similarities (similarity > 0.8)
WHERE similarity > 0.8
// Create a similarity relationship between users
MERGE (u1)-[:SIMILAR_TO {similarity: similarity}]->(u2)
RETURN u1, u2, similarity
ORDER BY similarity DESC
LIMIT 20;

// Find similar users (neighbors)
MATCH (u1:User {id: $userId})-[r1:RATED]->(common:Movie)<-[r2:RATED]-(u2:User)
WHERE u1 <> u2
WITH u1, u2,
     collect(toFloat(r1.rating)) AS v1,
     collect(toFloat(r2.rating)) AS v2
WHERE size(v1) > 1

// Compute cosine similarity
WITH u1, u2,
     reduce(dot = 0.0, i IN range(0, size(v1)-1) | dot + (v1[i] * v2[i])) AS dotProduct,
     sqrt(reduce(s1 = 0.0, i IN range(0, size(v1)-1) | s1 + (v1[i]^2))) AS norm1,
     sqrt(reduce(s2 = 0.0, i IN range(0, size(v2)-1) | s2 + (v2[i]^2))) AS norm2
WITH u1, u2,
     CASE WHEN norm1 = 0 OR norm2 = 0 THEN 0 ELSE dotProduct / (norm1 * norm2) END AS sim
ORDER BY sim DESC
LIMIT 30

// Compute mean ratings for target user and neighbors
MATCH (u1)-[rU:RATED]->()
WITH u1, avg(toFloat(rU.rating)) AS meanUser, collect({u2: u2, sim: sim}) AS sims

// Predict ratings for movies not yet rated by the user
UNWIND sims AS s
MATCH (neighbor)-[r3:RATED]->(rec:Movie)
WHERE id(neighbor) = id(s.u2) AND NOT (u1)-[:RATED]->(rec)
WITH u1, meanUser, rec, s.sim AS sim, r3.rating AS neighborRating
WITH u1, meanUser, rec,
     sum(sim) AS sumSim,
     sum(sim * (toFloat(neighborRating) - meanUser)) AS weightedSum

// Normalize and attenuate weights
WITH u1, rec, meanUser, weightedSum, sumSim,
     (1 - exp(-sumSim / 20.0)) AS attenuation,
     sumSim AS confidence

// Compute predicted rating blending with global average
MATCH (:User)-[rAll:RATED]->()
WITH u1, rec, meanUser, weightedSum, sumSim, attenuation, confidence,
     avg(toFloat(rAll.rating)) AS global_avg
WITH rec, confidence,
     CASE
         WHEN sumSim = 0 THEN NULL
         ELSE (
             0.7 * (meanUser + ((weightedSum / sumSim) * attenuation))
             + 0.3 * global_avg
         )
     END AS raw_predicted

// Clamp predicted rating to [1,5]
WITH rec, confidence,
     CASE
         WHEN raw_predicted IS NULL THEN NULL
         WHEN raw_predicted < 1 THEN 1
         WHEN raw_predicted > 5 THEN 5
         ELSE raw_predicted
     END AS PredictedRating

// Save predicted rating for collaborative filtering
SET rec.predictedCF = PredictedRating

// Return top recommendations
RETURN
     rec.title AS RecommendedMovie,
     round(PredictedRating, 2) AS PredictedRating,
     round(confidence, 3) AS ConfidenceScore
ORDER BY PredictedRating DESC, ConfidenceScore DESC
LIMIT 10;

// Predictions for randomly selected movies
MATCH (u:User {id: 672})
MATCH (m:Movie)
WHERE NOT (u)-[:RATED]->(m)
  AND m.predictedCB IS NOT NULL
  AND m.predictedCF IS NOT NULL
WITH m ORDER BY rand() LIMIT 10
RETURN 
    m.title AS Movie,
    round(m.predictedCB, 2) AS ContentBased_Rating,
    round(m.predictedCF, 2) AS Collaborative_Rating,
    abs(m.predictedCB - m.predictedCF) AS Difference
ORDER BY Difference DESC;



