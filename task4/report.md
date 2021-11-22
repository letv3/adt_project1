# PDT2021 Zadanie 4
## Oleksandr Lytvyn

git: https://github.com/letv3/adt_project1/blob/main/task4

src: https://github.com/letv3/adt_project1/blob/main/task4/src_task4.ipynb

**1. DATOVY MODEL**

Ako prvou ulohou bolo vytvorit vzorovy json objekt ktory by reprezentoval jednotlivy tweet.
```json
"tweet1":{
    "tweet_id": "1",
    "content": "Here will be some conspiracy shit #DeepStateVirus #Qanon",
    "happened_at": "2020-05-12T13:48:20+02:00",
    "favourite_count": 10,
    "retweet_count": 3,
    "parent_id": "0"    
    "user": {
      "user_id": "1068",
      "screen_name": "kurt",
      "name": "Kurt Schrader"
    },
    "hashtags": ["DeepStateVirus","Qanon"]
  }
```
Tento model obsahuje vsetky dolezite atributy pre tweet tak isto ako sql zaznam. To znamena ze
v tomto modeli som rozhodol ponechat _tweet_id, content, happened_at, favourite_count, retweet_count a parent_id_.
Ponechal som tieto atriuty preto ze oni su reprezentuje tweet ako celok, a teda tweet uz nebude tweetom 
(tak ako ja to rozumiem) ak nieco odtialto odstranime.
Dalej na miesto author_id som sa rozhodol pouzit vnoreny objekt "user",
ktory by obsahoval najdolezitejsie user info a to _user_id, name a screen_name_. 
Vyber tychto atributov bol inspirovany realnym vyhladom tweetov.

![tweet](./img.png)



Kde vidime ze pre zakladne zobrazovanie tweetu potrebujeme iba _name_ a _screen name_. Atribut
_user_id_ musi byt aby sme vedieli jednoznacne a rychlo identifikovat pouzivatela. Teoreticky by sme vedieli 
pridat tam vsetky atributy pouzivatela, ale podla mojho nazoru je to redundatne a nema ziaden vyznam.

Dalsim atributom tweetu je _hashtags_ ktore obsahuje array stringov  (hashtagov). Hashtagy su v podobe
jednotlivych stringov preto ze to dava nam moznost vyhladania(a zhody jedneho s pola), porovnanie a grupovanie
twetov do skupin, ktore budu obashovat urcite hashtagy. Pridavanie hashtagu ako celeho objektu v  tvare
`{"hashtag_id": "12323423423","value": "#qanon"}` je redundantne preto ze samotny hashtag nema ziaddnu hodnotu v
(podla mojho nazoru) ak exituje bez tweetu. To znamena ze hashtag vzdy bude embedovany do tweetu a vsetky analyzy
pribehaju na tweetoch, nie na hashtagoch. Teda hashatag sluzi ako identifikator pre tweet (oznamuje ze tweet patri do
niektoreho topicu atd). A teda otazka, naco potrebujeme identetifikatory pre indetifikator?

Nepridal som taktiez do objektu tweet aj mentions, preto ze nebolo to potrebne v dalsich ulohah.
Ale ak by to chybalo tak by to vyzeralo ako priklad nizsie. User_id pre indetifikaciu usera a name pre zobrazovanie 
mentiona v texte
```json
"mentions":[
  {"user_id": "12312314324", "name": "PussyDestroyer2005"},
  {"user_id": "97097979878", "name": "pimp_gg"}
]
```

**2. Transformacia a importovanie kolekcie dokumentov**

Vytvorenie pomocnych tabuliek a indexov v PostgreSQL
```sql
SELECT th.hashtag_id, th.tweet_id INTO conspiracy_tweet_hashtags
FROM tweet_hashtags th WHERE th.hashtag_id in (SELECT id FROM all_conspiracy_hashtags) 


SELECT cth.hashtag_id, cth.tweet_id, ach.value INTO conspiracy_tweet_hashtags_values
FROM conspiracy_tweet_hashtags cth
FULL JOIN all_conspiracy_hashtags ach on cth.hashtag_id = ach.id

CREATE INDEX tweet_index ON conspiracy_tweet_hashtags_values (tweet_id)
```

Vytvorenie tabulky json dokumentov pre dalsie operacie.

```sql
SELECT row_to_json(t) INTO conspiracy_tweets_json
FROM (SELECT
		ct.id as tweet_id,
		ct.content as content,
		ct.happened_at as happened_at,
		ct.parent_id as parent_id,
		ct.retweet_count as retweet_count,
		ct.favorite_count as favorite_count,
	  	(SELECT row_to_json(u)
		 FROM (	SELECT
					ca.id as user_id,
					ca.name as name,
					ca.screen_name as screen_name
		  	  	FROM conspiracy_accounts ca 
			   	WHERE ca.id = ct.author_id
			  ) u
		) as user,
	  	(SELECT json_agg(h.value)
		 FROM (	SELECT 
			   		cthv.value	  	
			  	FROM conspiracy_tweet_hashtags_values cthv 
			  	WHERE cthv.tweet_id = ct.id
			  ) h
		) as hashtags	  	
	  FROM conspiracy_tweets ct 	
) t;
```

Dalsie manipulacie s udajmi som robil pomocou pythonu, resp. stiahnutie celej tabulky jsonov
a zapisovanie ich do mongodb.

```python
#retrieve from postgresql
connection = sqlalchemy.create_engine(f'postgresql://{pg_user}:{pg_password}'
                                      f'@{pg_address}:5432/{pg_database}')
documents  = connection.execute("SELECT ctj.row_to_json FROM conspiracy_tweets_json ctj")
docs = [doc['row_to_json'] for doc in documents]
#write to mongo

local_client = pymongo.MongoClient('localhost', 27017)
local_db = local_client.local
local_tweets = local_db.tweets
local_tweets.insert_many(docs)
```
Zapisovanie 2147240 tweetov do mongodb mi zbehlo za 26 sec.

**3. Dopyty**
Dopyty som tiez robil v pythone, ked ze je to pre mna viac pohodlnejsie nez cez mongo shell

   1. Vypísať posledných 10 tweetov accountu so screen_name = Marndin12, spolu s údajmi o accounte
```python
local_tweets.find({"user.screen_name": "Marndin12"}).sort([('happened_at', -1)]).limit(10)
```
Ako vystup som dostal 10 tweetov, davam sem iba 1, dalsie su ulozene v python notebook. 
**[git](https://github.com/letv3/adt_project1/blob/main/task4/src_task4.ipynb)**
```
tweet_id:1232257093316550657
content: Personally, I don't buy into the Corona Virus being a natural event. It's more likely to have been executed by the NWO to move agenda 2030 forward. Here's a short song I released BEFORE the outbreak - https://t.co/8F3GRJBy3e
 #agenda21 #agenda2030 #georgiaguidestones  Plz Share
happend_at: 2020-02-25T11:52:39+01:00
parent_id: None
retweet_count: 7
favorite_count: 18
user: {'user_id': 3003720760, 'name': 'Martin Noakes', 'screen_name': 'Marndin12'}
hashtags: ['agenda21']
```
   2. Vypísať prvých 10 tweetov - text, meno autora, dátum tweetu a hashtagy, 
ktoré retweetujú tweet s id = 1243427980199641088 (1246874043682299904 podla slacku)
```python
local_tweets.find({"parent_id": "1246874043682299904"}).sort([('happened_at', 1)]).limit(10)
```
Ako vystup som dostal 2 tweety, ktore vyzeraju nasledovne
```
tweet_id:1246908249577787393
content: RT @AgainstTideTV: This is a war, China's worse than Soviet Russia. #BoycottChina  and #MakeChinaPay #ChinaLiedPeopleDied - @SolomonYue @GO…
happend_at: 2020-04-05T23:11:07+02:00
parent_id: 1246874043682299904
retweet_count: 17
favorite_count: 0
user: {'user_id': 1184554425479761920, 'name': 'Zawdzki Pawel', 'screen_name': 'ZawdzkiP'}
hashtags: ['ChinaLiedPeopleDied']

tweet_id:1247109014694932481
content: RT @AgainstTideTV: This is a war, China's worse than Soviet Russia. #BoycottChina  and #MakeChinaPay #ChinaLiedPeopleDied - @SolomonYue @GO…
happend_at: 2020-04-06T12:28:53+02:00
parent_id: 1246874043682299904
retweet_count: 17
favorite_count: 0
user: {'user_id': 885448167168364544, 'name': 'Tomasz Trembowski', 'screen_name': 'TomaszTrembowsk'}
hashtags: ['ChinaLiedPeopleDied']
```