import Foundation

enum ToolPrompts {
    // MARK: - AI Bar Generator
    static let aiBarGenerator = """
    Craft lyrics that directly follow and rhyme with {input} last word, ensuring the new line is of similar length and strictly adheres to the original context and rhyme pattern. Use wordplay, similes, or metaphors that directly relate to and expand upon the meaning of {input}, but ensure that every element introduced is contextually bound to the users topic, avoiding any deviation or inclusion of unrelated content. You may deviate only if each rhyme progresses the story in a sequential way from the main topic. Avoid any repetitive phrases or words that symbolizes a chorus or hook in a song.
    """
    
    // MARK: - Alliterate It
    static let alliterateIt = """
    Write an alliteration for {input}. The alliteration should be in the same context as the phrase. Only use slang that a rap fan would use.
    """
    
    // MARK: - Chorus Creator
    static let chorusCreator = """
    [Insert what your song is about here]: {input}
    
    Create a chorus that ensures every element introduced is contextually bound to the user's lyrics, avoiding any deviation or inclusion of unrelated content.
    """
    
    // MARK: - Creative One-Liner
    static let creativeOneLiner = """
    Generate a unique metaphor or simile that reflects the idea behind '{input}' without rewording or using '{input}' itself. Focus on a single, coherent theme that resonates with '{input}', keeping it succinct and relevant.
    """
    
    // MARK: - Diss Track Generator
    static let dissTrackGenerator = """
    Create a diss track focusing on '{input}' that showcases advanced, yet understandable wordplay from start to finish, infused with the latest rap slang and expressions. The lyrics should remain on the cutting edge throughout, mirroring the evolution and trends of the rap scene from 2017 to the present, and continuously engaging today's audience with clever, precise critiques. Avoid outdated terms entirely, aligning the entire track with the flair and innovation of today's top rap artists. Ensure the narrative is consistently direct and impactful, with every verse, especially towards the end, maintaining dynamic and creative linguistic twists. The goal is to captivate with every line, ensuring no drop in quality or inventiveness, and avoiding complexity that detracts from the track's appeal.
    """
    
    // MARK: - Double Entendre
    static let doubleEntendre = """
    Create a double entendre for {input} but ensure that every element introduced is contextually bound to '{input}', avoiding any deviation or inclusion of unrelated content. Then explain the double entendre after.
    """
    
    // MARK: - Finisher
    static let finisher = """
    Craft lyrics that rhyme with the last word of '{input}', offering a seamless and creative continuation of the theme. Use advanced wordplay, dynamic similes, and compelling metaphors that expand upon the narrative introduced. Each new line should directly connect with the final word in '{input}', weaving a storyline that's both fresh and aligned with the essence of modern rap. Aim for a blend of innovation and tradition, mirroring the complexity and depth of today's rap scene, ensuring the lyrics not only rhyme with the last word of '{input}' but also elevate the entire narrative in an original and engaging way.
    """
    
    // MARK: - Flex-on-'em
    static let flexOnEm = """
    Write a song bragging about the accomplishments.

    {input}

    The new rap song should be something drake or future would rap, but leave out anything that would reveal it is drake or future who's rapping it.

    You may add clever lines that relate.
    """
    
    // MARK: - Imperfect Rhyme
    static let imperfectRhyme = """
    Create a slant rhyme for {input} but ensure that every element introduced is contextually bound to '{input}', avoiding any deviation or inclusion of unrelated content.
    """
    
    // MARK: - Industry Analyzer
    static let industryAnalyzer = """
    Lyrics: Analyze the lyrics of the song, identifying the themes, metaphors, and narrative. Give advice on how this can be more commercially listenable for the radio. Give advice on how specific lyrics can be more commercially listenable for the radio.

    Rhyme Structure: Analyze the rhythm and groove of the song, identifying the rhyme patterns. Give advice on how the rhyme structure can be adjusted to be more commercially listenable for the radio. Then talk about how often that rhyme structure is used in mainstream music, give a percentage.

    Similarities and Differences: Compare the analyzed song to other today's songs in today's rap genre or style, identifying similarities and differences in terms of structure, lyrics, and rhythm. Then talk about the specific lyric similarities that are in the song and mainstream rap music.

    Commercial Rating:
    Give advice on how this song can be made more relatable to today's average rap fan. Give advice on how this song can be adjusted for record labels to play it on the radio station (use specific lyrics from the song as examples).
    """
    
    // MARK: - Quadruple Entendre
    static let quadrupleEntendre = """
    Create a quadruple entendre for {input} but ensure that every element introduced is contextually bound to '{input}', avoiding any deviation or inclusion of unrelated content.

    Then explain the quadruple entendre after.
    """
    
    // MARK: - Rap Instagram Captions
    static let rapInstagramCaptions = """
    What's a clever line for an instagram caption, the context of this phrase: {input}

    Feel free to have it rhyme in a modern day rap style.
    """
    
    // MARK: - Rap Name Generator
    static let rapNameGenerator = """
    Make this name a rapper name, {input}. You may use alliteration. Take inspiration from today's hiphop artists. ONLY use slang that a culturally relevant rap fan would use in the current year. Don't use the same name.
    """
    
    // MARK: - Shapeshift
    static let shapeshift = """
    Create one homophone for {input} where the starting sound is identical to the original word, and use slant rhymes only within the ending part of the word. Avoid using any different letters at the beginning. 

    Then explain the sounds after, and the meaning of the new result.
    """
    
    // MARK: - Triple Entendre
    static let tripleEntendre = """
    Create a triple entendre for {input} but ensure that every element introduced is contextually bound to '{input}', avoiding any deviation or inclusion of unrelated content.

    Then explain the triple entendre after.
    """
    
    // MARK: - Ultimate Come Up Song
    static let ultimateComeUpSong = """
    * you're a song writer and your job is to write a story of an issue being resolved using details from {input} but stealing the style and words from {artist's-name}.

    ** make sure to apply those restriction and follow them directly and don't skip any of them;

    ***
    output with no introduction, no explanation, only lyrics.

    DON'T MAKE ANY MISTAKES, check if you did any.

    only return lyrics and nothing else.

    1. Do not include {artist's-name}

    2. Do not include any input words and prompt words.
    """
} 
