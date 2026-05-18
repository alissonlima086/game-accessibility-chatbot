import re
from collections import Counter

STOPWORDS = {
    "de", "da", "do", "das", "dos", "e", "é", "em", "para", "por",
    "com", "um", "uma", "uns", "umas", "no", "na", "nos", "nas",
    "se", "que", "como", "mais", "mas", "ou", "já", "também",
    "the", "and", "is", "in", "to", "of", "for", "on", "with",
    "as", "by", "at", "from", "this", "that", "it", "an", "be"
}


class KeywordProcessor:

    def extract_keywords(self, text: str, top_n: int = 10):
        words = re.findall(r'\w+', text.lower())

        filtered = [
            w for w in words
            if len(w) > 3 and w not in STOPWORDS
        ]

        most_common = Counter(filtered).most_common(top_n)

        return [word for word, _ in most_common]