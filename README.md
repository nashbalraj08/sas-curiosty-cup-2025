# 📊 SAS Project: Gamification in Education

## 🎯 About This Repository
This repository contains our project for **The Curiosity Cup 2025**, a global SAS student competition. The project explores how **gamification in education** impacts student engagement and learning outcomes, focusing on **Coursera course ratings** as a key performance metric.

## 🔍 Project Objective
The primary objective is to **analyze the effectiveness of gamification in online learning** by comparing course rating scores and engagement levels on Coursera. Given the lack of retention rate data, we utilize alternative metrics, such as:
- **Course rating scores** as a proxy for course quality and learner satisfaction.
- **Student enrollment numbers** to assess popularity.
- **Retention rates** (derived from reviews per enrolled student) as an engagement measure.

## 📌 Key Insights
- **Gamification and Engagement**: Gamified courses tend to receive higher ratings and engagement compared to traditional learning methods.
- **Ratings Distribution**: Most courses are rated between **4.5 and 5.0**, indicating high learner satisfaction.
- **Course Duration**: **Shorter courses** tend to have slightly higher ratings, but the effect is minimal.
- **Difficulty Level**: No significant correlation was found between course difficulty (Beginner, Intermediate, Advanced) and ratings.
- **Course Providers**: **Tech companies (e.g., Google, IBM)** generally receive higher ratings compared to university courses.
- **Skills & Ratings**: Courses on **Python, Machine Learning, and Data Analysis** tend to score higher.
- **Predictive Modelling**: Given the results, the **6-leaf pruned tree** is the most appropriate model, as it balances predictive accuracy, interpretability, and generalization while avoiding excessive complexity and overfitting.

## 🛠 Methodology
1. **Data Collection & Cleaning**
   - Sourced from Kaggle and imported into **SAS OnDemand for Academics**.
   - Handled missing values using the **5% rule**.
   - Standardized course reviews and enrollment data.
2. **Feature Engineering**
   - Created a **retention rate metric** based on reviews per enrolled student.
   - Classified organizations as **universities vs. tech companies**.
3. **Exploratory Data Analysis (EDA)**
   - Generated correlation matrices and visualizations.
   - Analyzed the impact of **course duration, difficulty level, and provider type** on ratings.
4. **Modeling & Predictions**
   - Used **Regression Trees(pruned and unpruned)** to predict course ratings based on features like **course difficulty, provider type, and enrollment numbers**.

## 📂 How to View the Project
- **SAS OnDemand for Academics**: Open **"EDA program.sas"** in SAS to view the applying Methodology section.
- **Final Paper**: A structured document with all methodologies, results, and discussions can be found in the **"Curiosity Cup 2025 Gamification in Education"**

---


