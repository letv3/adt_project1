-- ULOHA 1, FILTROVAT TWEETS podla hashtagu
-- RIESENIE 1
SELECT COUNT(tweets.id)
-- 	   tweets.content as tweet_text,
-- 	   tweets.id as tweet_id,
-- 	   tweets.happened_at as tweet_date,
-- 	   tweets.author_id as tweet_author,
FROM tweets
JOIN tweet_hashtags on tweet_hashtags.tweet_id = tweets.id
JOIN hashtags on hashtags.id = tweet_hashtags.hashtag_id
AND lower(hashtags.value) IN (SELECT lower(hashtag_value) FROM conspiracy_hashtags)

-- RIESENIE 2

SELECT * FROM tweets 
WHERE tweets.id IN (
	SELECT th.tweet_id FROM tweet_hashtags th WHERE th.hashtag_id IN (
		SELECT h.id FROM hashtags h WHERE lower(h.value) IN (
			SELECT lower(hashtag_value) FROM conspiracy_hashtags
		)
	)
)

-- ULOHA 2