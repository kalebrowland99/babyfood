#!/usr/bin/env python3
"""
Analyze the Spotify CSV dataset to understand its structure
"""

import pandas as pd
import sys

def analyze_csv_structure(filename):
    print(f"🔍 Analyzing {filename}...")
    
    try:
        # Read just the first few rows to understand structure
        print("📊 Loading first 5 rows...")
        sample = pd.read_csv(filename, nrows=5)
        
        print(f"\n📋 Dataset Info:")
        print(f"Columns: {len(sample.columns)}")
        print(f"Column names: {list(sample.columns)}")
        
        print(f"\n📝 Sample Data:")
        print(sample.head())
        
        print(f"\n🗂️ Data Types:")
        print(sample.dtypes)
        
        # Check for year/date columns
        year_columns = [col for col in sample.columns if 'year' in col.lower() or 'date' in col.lower() or 'release' in col.lower()]
        print(f"\n📅 Potential date/year columns: {year_columns}")
        
        # Check for lyrics column
        lyrics_columns = [col for col in sample.columns if 'lyric' in col.lower() or 'text' in col.lower()]
        print(f"\n🎵 Potential lyrics columns: {lyrics_columns}")
        
        # Check total row count (this might take a moment)
        print(f"\n📏 Counting total rows...")
        total_rows = sum(1 for line in open(filename)) - 1  # -1 for header
        print(f"Total songs: {total_rows:,}")
        
        # Sample year data if year column exists
        if year_columns:
            year_col = year_columns[0]
            print(f"\n📊 Year distribution sample:")
            year_sample = pd.read_csv(filename, usecols=[year_col], nrows=1000)
            print(year_sample[year_col].value_counts().head(10))
            print(f"Min year: {year_sample[year_col].min()}")
            print(f"Max year: {year_sample[year_col].max()}")
        
        return sample.columns.tolist(), year_columns, lyrics_columns
        
    except Exception as e:
        print(f"❌ Error analyzing CSV: {e}")
        return None, None, None

if __name__ == "__main__":
    filename = "spotify_dataset.csv"
    columns, year_cols, lyrics_cols = analyze_csv_structure(filename)
    
    if columns:
        print(f"\n✅ Analysis complete!")
        print(f"📋 Found {len(columns)} columns")
        print(f"📅 Year columns: {year_cols}")
        print(f"🎵 Lyrics columns: {lyrics_cols}")
    else:
        print(f"\n❌ Analysis failed!") 