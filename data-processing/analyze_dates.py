#!/usr/bin/env python3
"""
Better analysis of date ranges in the Spotify dataset
"""

import pandas as pd
import re
from collections import Counter

def extract_year_from_date_string(date_str):
    """Extract year from complex date strings like '29th July 2022'"""
    if pd.isna(date_str):
        return None
    
    # Look for 4-digit year pattern
    year_match = re.search(r'\b(19|20)\d{2}\b', str(date_str))
    if year_match:
        return int(year_match.group())
    return None

def analyze_date_range(filename, sample_size=10000):
    print(f"🔍 Analyzing date range in {filename}...")
    
    try:
        # Read a larger sample to get better date coverage
        print(f"📊 Loading {sample_size:,} rows for date analysis...")
        sample = pd.read_csv(filename, usecols=['Release Date'], nrows=sample_size)
        
        print(f"\n📅 Sample of raw date formats:")
        print(sample['Release Date'].head(10).tolist())
        
        # Extract years from date strings
        print(f"\n🔧 Extracting years from date strings...")
        sample['Year'] = sample['Release Date'].apply(extract_year_from_date_string)
        
        # Remove rows where year extraction failed
        valid_years = sample['Year'].dropna()
        
        print(f"\n📊 Year Statistics:")
        print(f"Valid years extracted: {len(valid_years):,} / {len(sample):,}")
        print(f"Year range: {valid_years.min()} - {valid_years.max()}")
        
        # Count by year
        year_counts = Counter(valid_years)
        print(f"\n📈 Top 15 years by song count:")
        for year, count in year_counts.most_common(15):
            print(f"{year}: {count:,} songs")
        
        # Count songs from 2016+
        songs_2016_plus = len(valid_years[valid_years >= 2016])
        total_valid = len(valid_years)
        percentage = (songs_2016_plus / total_valid) * 100 if total_valid > 0 else 0
        
        print(f"\n🎯 Songs from 2016 onwards:")
        print(f"Count: {songs_2016_plus:,} / {total_valid:,} ({percentage:.1f}%)")
        
        return valid_years.min(), valid_years.max(), songs_2016_plus, total_valid
        
    except Exception as e:
        print(f"❌ Error analyzing dates: {e}")
        return None, None, None, None

if __name__ == "__main__":
    filename = "spotify_dataset.csv"
    min_year, max_year, songs_2016_plus, total = analyze_date_range(filename)
    
    if min_year:
        print(f"\n✅ Date analysis complete!")
        print(f"📅 Full year range: {min_year} - {max_year}")
        print(f"🎯 Songs 2016+: {songs_2016_plus:,} ({(songs_2016_plus/total)*100:.1f}%)")
    else:
        print(f"\n❌ Date analysis failed!") 