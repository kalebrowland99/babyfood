#!/usr/bin/env python3
"""
Process Spotify lyrics dataset to create rhyme database for iOS app
Filters for 2016+ songs and extracts word patterns for rhyme generation
"""

import pandas as pd
import sqlite3
import re
import string
from collections import Counter, defaultdict
import os
from datetime import datetime

class LyricsProcessor:
    def __init__(self, csv_filename, db_filename="rhyme_database.sqlite"):
        self.csv_filename = csv_filename
        self.db_filename = db_filename
        self.word_counts = Counter()
        self.rhyme_patterns = defaultdict(set)
        self.total_songs_processed = 0
        self.words_extracted = 0
        
    def extract_year_from_date(self, date_str):
        """Extract year from date string like '29th July 2022'"""
        if pd.isna(date_str):
            return None
        year_match = re.search(r'\b(19|20)\d{2}\b', str(date_str))
        return int(year_match.group()) if year_match else None
    
    def clean_word(self, word):
        """Clean and normalize a word for rhyme analysis"""
        # Remove punctuation and convert to lowercase
        cleaned = word.lower().strip(string.punctuation)
        # Remove numbers and special characters
        cleaned = re.sub(r'[^a-z]', '', cleaned)
        return cleaned if len(cleaned) >= 2 else None
    
    def extract_words_from_lyrics(self, lyrics_text):
        """Extract clean words from lyrics text"""
        if pd.isna(lyrics_text) or not lyrics_text:
            return []
        
        # Split into words and clean each one
        words = []
        for word in str(lyrics_text).split():
            cleaned = self.clean_word(word)
            if cleaned and len(cleaned) <= 15:  # Reasonable word length limit
                words.append(cleaned)
        
        return words
    
    def generate_rhyme_patterns(self, word):
        """Generate rhyme patterns for a word (2-4 character endings)"""
        patterns = []
        for length in range(2, min(5, len(word) + 1)):
            pattern = word[-length:]
            patterns.append(pattern)
        return patterns
    
    def process_chunk(self, chunk):
        """Process a chunk of the CSV data"""
        songs_in_chunk = 0
        words_in_chunk = 0
        
        for _, row in chunk.iterrows():
            # Extract year and filter for 2016+
            year = self.extract_year_from_date(row['Release Date'])
            if not year or year < 2016:
                continue
            
            # Extract words from lyrics
            words = self.extract_words_from_lyrics(row['text'])
            if not words:
                continue
            
            songs_in_chunk += 1
            words_in_chunk += len(words)
            
            # Count word frequencies
            for word in words:
                self.word_counts[word] += 1
                
                # Generate rhyme patterns
                patterns = self.generate_rhyme_patterns(word)
                for pattern in patterns:
                    self.rhyme_patterns[pattern].add(word)
        
        return songs_in_chunk, words_in_chunk
    
    def create_database(self):
        """Create optimized SQLite database for iOS app"""
        print(f"🗄️ Creating database: {self.db_filename}")
        
        # Remove existing database
        if os.path.exists(self.db_filename):
            os.remove(self.db_filename)
        
        conn = sqlite3.connect(self.db_filename)
        cursor = conn.cursor()
        
        # Create words table
        cursor.execute('''
            CREATE TABLE words (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                word TEXT UNIQUE NOT NULL,
                frequency INTEGER NOT NULL,
                ending_2 TEXT,
                ending_3 TEXT,
                ending_4 TEXT
            )
        ''')
        
        # Create rhyme patterns table for fast lookups
        cursor.execute('''
            CREATE TABLE rhyme_patterns (
                pattern TEXT NOT NULL,
                word TEXT NOT NULL,
                pattern_length INTEGER NOT NULL,
                PRIMARY KEY (pattern, word)
            )
        ''')
        
        print(f"📊 Inserting {len(self.word_counts):,} unique words...")
        
        # Filter words by minimum frequency (appear in at least 3 songs)
        min_frequency = 3
        filtered_words = {word: count for word, count in self.word_counts.items() 
                         if count >= min_frequency}
        
        print(f"🔍 After filtering (min {min_frequency} occurrences): {len(filtered_words):,} words")
        
        # Insert words into database
        word_data = []
        pattern_data = []
        
        for word, frequency in filtered_words.items():
            # Generate endings for quick rhyme lookups
            ending_2 = word[-2:] if len(word) >= 2 else None
            ending_3 = word[-3:] if len(word) >= 3 else None
            ending_4 = word[-4:] if len(word) >= 4 else None
            
            word_data.append((word, frequency, ending_2, ending_3, ending_4))
            
            # Add rhyme patterns
            patterns = self.generate_rhyme_patterns(word)
            for pattern in patterns:
                pattern_data.append((pattern, word, len(pattern)))
        
        # Batch insert words
        cursor.executemany('''
            INSERT INTO words (word, frequency, ending_2, ending_3, ending_4)
            VALUES (?, ?, ?, ?, ?)
        ''', word_data)
        
        # Batch insert patterns
        cursor.executemany('''
            INSERT INTO rhyme_patterns (pattern, word, pattern_length)
            VALUES (?, ?, ?)
        ''', pattern_data)
        
        # Create indexes for fast queries
        print(f"📈 Creating database indexes...")
        cursor.execute('CREATE INDEX idx_ending_2 ON words(ending_2)')
        cursor.execute('CREATE INDEX idx_ending_3 ON words(ending_3)')
        cursor.execute('CREATE INDEX idx_ending_4 ON words(ending_4)')
        cursor.execute('CREATE INDEX idx_frequency ON words(frequency DESC)')
        cursor.execute('CREATE INDEX idx_pattern ON rhyme_patterns(pattern)')
        cursor.execute('CREATE INDEX idx_pattern_length ON rhyme_patterns(pattern_length)')
        
        # Add metadata table
        cursor.execute('''
            CREATE TABLE metadata (
                key TEXT PRIMARY KEY,
                value TEXT
            )
        ''')
        
        metadata = [
            ('created_date', datetime.now().isoformat()),
            ('total_songs_processed', str(self.total_songs_processed)),
            ('total_words_extracted', str(self.words_extracted)),
            ('unique_words', str(len(filtered_words))),
            ('min_frequency', str(min_frequency)),
            ('year_filter', '2016+'),
            ('version', '1.0')
        ]
        
        cursor.executemany('INSERT INTO metadata (key, value) VALUES (?, ?)', metadata)
        
        conn.commit()
        conn.close()
        
        # Get database file size
        db_size = os.path.getsize(self.db_filename) / (1024 * 1024)  # MB
        print(f"✅ Database created successfully!")
        print(f"📁 Size: {db_size:.1f} MB")
        print(f"📊 Contains {len(filtered_words):,} unique words")
        
    def process_csv(self, chunk_size=5000):
        """Process the entire CSV file in chunks"""
        print(f"🚀 Starting processing of {self.csv_filename}")
        print(f"📏 Processing in chunks of {chunk_size:,} rows")
        print(f"🎯 Filtering for songs from 2016 onwards")
        
        chunk_num = 0
        
        try:
            # Process CSV in chunks to handle memory efficiently
            for chunk in pd.read_csv(self.csv_filename, chunksize=chunk_size):
                chunk_num += 1
                print(f"📦 Processing chunk {chunk_num} ({len(chunk):,} rows)...")
                
                songs_processed, words_extracted = self.process_chunk(chunk)
                self.total_songs_processed += songs_processed
                self.words_extracted += words_extracted
                
                print(f"   ✅ Chunk {chunk_num}: {songs_processed:,} songs, {words_extracted:,} words")
                
                # Progress update every 10 chunks
                if chunk_num % 10 == 0:
                    print(f"🔄 Progress: {self.total_songs_processed:,} songs, {len(self.word_counts):,} unique words")
            
            print(f"\n🎉 Processing complete!")
            print(f"📊 Final stats:")
            print(f"   Songs processed: {self.total_songs_processed:,}")
            print(f"   Words extracted: {self.words_extracted:,}")
            print(f"   Unique words: {len(self.word_counts):,}")
            
            # Create database
            self.create_database()
            
        except Exception as e:
            print(f"❌ Error processing CSV: {e}")
            raise

def main():
    print("🎵 Lyric Processor for Rhyme Database Creation")
    print("=" * 50)
    
    processor = LyricsProcessor("spotify_dataset.csv")
    processor.process_csv()
    
    print(f"\n✅ All done! Database ready for iOS integration.")
    print(f"📁 Database file: {processor.db_filename}")

if __name__ == "__main__":
    main() 