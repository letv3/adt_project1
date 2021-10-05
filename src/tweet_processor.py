import re


class TweetProcessor:

    def __remove_newline(self, tweet: str) -> str:
        newline_pattern = re.compile(r"\n")
        return newline_pattern.sub(r'', tweet)

    def __remove_hashtags(self, tweet: str) -> str:
        hashtag_pattern = re.compile(r"\#\w*")
        return hashtag_pattern.sub(r'', tweet)

    def __remove_mentions(self, tweet: str) -> str:
        mention_pattern = re.compile(r"(RT )?@[\w]+(:)?")
        return mention_pattern.sub(r'', tweet)

    def __remove_links(self, tweet:str) -> str:
        link_pattern = re.compile(r"https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b"
                                  r"([-a-zA-Z0-9()@:%_\+.~#?&//=]*)")
        return link_pattern.sub(r'', tweet)

    def __remove_emojis(self, tweet:str) -> str:
        emoji_pattern = re.compile(u"["
                        u"\U0001F600-\U0001F64F"  # emoticons
                        u"\U0001F300-\U0001F5FF"  # symbols & pictographs
                        u"\U0001F680-\U0001F6FF"  # transport & map symbols
                        u"\U0001F1E0-\U0001F1FF"  # flags (iOS)
                        u"\U00002500-\U00002BEF"  # chinese char
                        u"\U00002702-\U000027B0"
                        u"\U00002702-\U000027B0"
                        u"\U000024C2-\U0001F251"
                        u"\U0001f926-\U0001f937"
                        u"\U00010000-\U0010ffff"
                        u"\u2640-\u2642" 
                        u"\u2600-\u2B55"
                        u"\u200d"
                        u"\u23cf"
                        u"\u23e9"
                        u"\u231a"
                        u"\ufe0f"  # dingbats
                        u"\u3030]+", flags=re.UNICODE)
        return emoji_pattern.sub(r'', tweet)

    def prepare_tweet(self, tweet: str) -> str:
        tweet_modified = self.__remove_hashtags(tweet)
        tweet_modified = self.__remove_links(tweet_modified)
        tweet_modified = self.__remove_mentions(tweet_modified)
        tweet_modified = self.__remove_emojis(tweet_modified)
        tweet_modified = self.__remove_newline(tweet_modified)
        return tweet_modified

