# PDT2021 Zadanie 5 - Elastic
## Oleksandr Lytvyn

git: https://github.com/letv3/adt_project1/blob/main/task5


1. Rozbehajte si 3 inštancie Elasticsearch-u
Spravil som to pomocou defaultneho docker-compose suboru, ktory je zverejneny na stranke.
Mal som a zvacsit `vm.max_map_count` do 262144. 
```shell
wsl -d docker-desktop
sysctl -w vm.max_map_count=262144
```
Responce on GET `localhost:9200/_cat/nodes?v`
```
ip         heap.percent ram.percent cpu load_1m load_5m load_15m node.role   master name
172.19.0.3           34          44   1    0.50    0.19     0.10 cdfhilmrstw *      es02
172.19.0.4           23          44  13    0.50    0.19     0.10 cdfhilmrstw -      es03
172.19.0.2           56          44   1    0.50    0.19     0.10 cdfhilmrstw -      es01
```


2. Vieme vytvorit index pomocou  PUT api requestu `localhost:9200/tweets`, pri vytvorenie indexu zadefinujeme
pocet shardov 2 (apache lucene index instances) a pocet replik 2. A tak tie definujem coerce false aby zabranit
automatickomu type castingu. A tak tie definujem normilizer ktory potom sa pouzie pri mapovani

Requst body:
```json
{
  "settings": {
    "number_of_replicas": 2,
    "number_of_shards": 2,
    "index.mapping.coerce": "false",
    "analysis": {
      "normalizer": {
        "lowercase_normalizer": {
          "type": "custom",
          "filter": ["lowercase"]
        }
      }
    }
  }
}
```
Responce:
```json
{
    "acknowledged": true,
    "shards_acknowledged": true,
    "index": "tweets"
}
```
3. Vytvorte vlastne anlazery. Aby vytvorit analyzery musim najpr zatvori index pomocou POST `localhost:9200/tweets/_close`
Som pomenil poradie uloh aby zbytocne neupdatovat mapping, a zadefinovat vsetky analyzery pred definovanim mappingu. 
   1. ENGLANDO : PUT `localhost:9200/tweets/_settings`, REQUEST BODY:
    ```json
    {
       "analysis": {
         "filter": {
           "english_stop": {
             "type":       "stop",
             "stopwords":  "_english_" 
           },
           "english_stemmer": {
             "type":       "stemmer",
             "language":   "english"
           },
           "english_possessive_stemmer": {
             "type":       "stemmer",
             "language":   "possessive_english"
           }
         },
         "analyzer": {
           "englando": {
             "tokenizer":  "standard",
             "char_filter": [
               "html_strip"
             ],
             "filter": [
               "english_possessive_stemmer",
               "lowercase",
               "english_stop",
               "english_stemmer"
             ]
           }
         }
       }
    }
    ```
    RESPONCE :
    ```json
    {
        "acknowledged": true
    }
    ```
   2. custom_ngram  : PUT `localhost:9200/tweets/_settings`, REQUEST BODY:
    ```json
    {
        "index": {
          "max_ngram_diff": 9
        },
        "analysis": {
          "filter": {
            "filter_ngrams": {
              "type":"ngram",
              "min_gram": 1,
              "max_gram": 10
            }
          },
          "analyzer": {
            "custom_ngram": {
              "tokenizer":  "standard",
              "char_filter": [
                "html_strip"
              ],
              "filter": [
                "lowercase",
                "asciifolding",
                "filter_ngrams"
              ]
            }
          }
        }
    }
    ```
    RESPONCE :
    ```json
    {
        "acknowledged": true
    }
    ```
   3. custom_shingles : PUT `localhost:9200/tweets/_settings`, REQUEST BODY:
    ```json
    {
        "analysis": {
          "filter": {
            "filter_shingles": {
              "type":"shingle",
              "token_separator": ""
            }
          },
          "analyzer": {
            "custom_shingles": {
              "tokenizer":  "standard",
              "char_filter": [
                "html_strip"
              ],
              "filter": [
                "lowercase",
                "asciifolding",
                "filter_shingles"
              ]
            }
          }
        }
    }
    ```
    RESPONCE :
    ```json
    {
        "acknowledged": true
    }
Potom musime otvorit index pomocou POST `localhost:9200/tweets/_open`.
4. Vytvorte mapping pre tweet. Pouzil taku istu structuru objektov ako pri zadanie s mongo.
Pre vytvorenie mappingu som pouzil PUT `localhost:9200/tweets/_mapping`
```json
{
  	"dynamic":false,
    "properties": {
      "tweet_id": {
        "type": "keyword"
      },
      "content": {
        "type": "text",
        "analyzer": "englando"
      },
      "happened_at":{
      	"type": "date",
      	"index": "false"
      },
      "favourite_count":{
      	"type": "integer",
      	"index": "false"
      },
      "retweet_count": {
      	"type": "integer",
      	"index": "false"
      },
      "parent_id": {
      	"type": "keyword",
      	"index": "false"
      },
  	  "hashtags": {
	  	"type": "keyword",
	  	"normalizer": "lowercase_normalizer"
	  	
	  },	
      "author": {
		"type":"nested",
		"properties":{
			"id": {"type": "keyword"},
			"name": {
				"type": "text",  
				"analyzer": "englando", 
				"search_analyzer": "custom_ngram",
				"search_quote_analyzer": "custom_shingles"
			},
			"screen_name": {
				"type": "text",  
				"analyzer": "englando",
				"search_analyzer": "custom_ngram"
			},
			"description": {
				"type": "text",  
				"analyzer": "englando", 
				"search_quote_analyzer": "custom_shingles"
			},
			"followers_count": {"type": "integer", "index": "false"},
			"friends_count": {"type": "integer", "index": "false"},
			"statuses_count": {"type": "integer","index": "false"}
		}
	  }
	}
  } 
```
RESPONCE BODY :
```json
{
    "acknowledged": true
}
```
5. Vytvorte Bulk pre normalizovane tweety. Vytorim tabluku s PostgreSQL kde budem mat dva stlpca: object(2. riadok) a metadata
   (1. riadok). 
```json lines
{"index" : {"_id" : "1260962186115059712"}} 
{"tweet_id":"1260962186115059712","content":"https://t.co/cxy32u7ShU\\r\\n\\r\\n#qanon","happened_at":"2020-05-14T15:56:27+02:00","parent_id":null,"retweet_count":510,"favorite_count":0,"user":{"id":1142191393349222401,"screen_name":"TheStor07484946","name":"TheStorm","description":"","followers_count":460,"friends_count":155,"statuses_count":191608},"hashtags":["qanon"]}
```
```sql
SELECT row_to_json(t) as object, json_build_object('index', json_build_object('_id', t.tweet_id)) as metadata
INTO conspiracy_tweets_json_metadata
FROM (SELECT
		ct.id as tweet_id,
		ct.content as content,
		ct.happened_at as happened_at,
		ct.parent_id as parent_id,
		ct.retweet_count as retweet_count,
		ct.favorite_count as favorite_count,
	  	(SELECT row_to_json(u)
		 FROM (	SELECT *
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
A zapisem 5000 tweetov do textoveho suboru
```sql
COPY (SELECT ctm.metadata, ctm.object   
	  FROM conspiracy_tweets_json_metadata ctm LIMIT 5000) 
TO 'd:\elasticbulks\tweets_5000'
DELIMITER E'\t'
```
Ale som sa narazil na problem ze `COPY` nepozna `\n` ako delimiter, a preto som este napisal python script
na ktory vymeni vsetky `\t` za `\n`.
```python
import re
with open('d:/elasticbulks/tweets_5000', 'r') as f:
    all_lines = f.readlines()

with open('d:/elasticbulks/tweets_5000_n', 'w') as fn:
    for line in all_lines:
        res = re.sub(r'\t', '\n', line)
        fn.write(res)
```
Vo vysledku dostaneme subor v nasledujucom tvare `metadata\n object\n`
```json lines
{"index" : {"_id" : "1260962186115059712"}}
{"tweet_id":"1260962186115059712","content":"https://t.co/cxy32u7ShU\\r\\n\\r\\n#qanon","happened_at":"2020-05-14T15:56:27+02:00","parent_id":null,"retweet_count":510,"favorite_count":0,"user":{"id":1142191393349222401,"screen_name":"TheStor07484946","name":"TheStorm","description":"","followers_count":460,"friends_count":155,"statuses_count":191608},"hashtags":["qanon"]}
{"index" : {"_id" : "1261355993377566720"}}
{"tweet_id":"1261355993377566720","content":"Q sent this. #QAnon https://t.co/ZCpTQNJzrr","happened_at":"2020-05-15T18:01:18+02:00","parent_id":null,"retweet_count":0,"favorite_count":0,"user":{"id":14344403,"screen_name":"MickBradyQ45","name":"Mick Brady","description":"","followers_count":884,"friends_count":1312,"statuses_count":1737},"hashtags":["QAnon"]}
{"index" : {"_id" : "1263536635976855552"}}
{"tweet_id":"1263536635976855552","content":"#ObamaGate\\r\\n\\r\\n#QAnon\\r\\n\\r\\n https://t.co/c4dJzGXPZo","happened_at":"2020-05-21T18:26:24+02:00","parent_id":null,"retweet_count":1,"favorite_count":0,"user":{"id":893857977538682880,"screen_name":"B_Rush1776","name":"DrBenjaminRush","description":"Q’d 3/25/19 Post #3184 #QAnon #WWG1WGA #MAGA #KAG","followers_count":13551,"friends_count":5179,"statuses_count":80249},"hashtags":["QAnon"]}
{"index" : {"_id" : "1263812784065830915"}}
{"tweet_id":"1263812784065830915","content":"How new are you to Q? #QAnon","happened_at":"2020-05-22T12:43:42+02:00","parent_id":null,"retweet_count":1835,"favorite_count":0,"user":{"id":1263808496438558722,"screen_name":"magoop2","name":"magoop","description":"","followers_count":5,"friends_count":44,"statuses_count":40},"hashtags":["QAnon"]}
```
6. Importujete dáta do Elasticsearchu prvych 5000 tweetov. To vieme spravit pomocou bulk api.
A konkrente pomocou POST `localhost:9200/tweets/_bulk`, a do vstupu dame subor s tweetami `d:/elasticbulks/tweets_5000_n`.
RESPONCE BODY:
```json
{
    "took": 2438,
    "errors": true,
    "items": [
        {
            "index": {
                "_index": "tweets",
                "_type": "_doc",
                "_id": "1260962186115059712",
                "_version": 1,
                "result": "created",
                "_shards": {
                    "total": 3,
                    "successful": 3,
                    "failed": 0
                },
                "_seq_no": 0,
                "_primary_term": 3,
                "status": 201
            }
        },
        {
            "index": {
                "_index": "tweets",
                "_type": "_doc",
                "_id": "1261355993377566720",
                "_version": 1,
                "result": "created",
                "_shards": {
                    "total": 3,
                    "successful": 3,
                    "failed": 0
                },
                "_seq_no": 1,
                "_primary_term": 3,
                "status": 201
            }
        },
        ...
      {
            "index": {
                "_index": "tweets",
                "_type": "_doc",
                "_id": "1266388190690041857",
                "status": 400,
                "error": {
                    "type": "mapper_parsing_exception",
                    "reason": "failed to parse",
                    "caused_by": {
                        "type": "i_o_exception",
                        "reason": "Unexpected character ('S' (code 83)): was expecting comma to separate Object entries\n at [Source: (ByteArrayInputStream); line: 1, column: 77]"
                    }
                }
            }
        }
}
```
A narazil som sa na problem kde analyzer nevie analizovat `\\"` znaky, a pocita ako `\\` (backslash) a `"` koniec stringu.
Pri tom este sa zostava dalsi text tweetu, ktory aj sposobuje error. Zaindexovalo celkovo 4717 tweetov.

GET `localhost:9200/_cat/indices?v`
```
health status index            uuid                   pri rep docs.count docs.deleted store.size pri.store.size
green  open   .geoip_databases Q33F6VbZQRWeJthpPVrMCw   1   1         42           22      103mb         51.5mb
green  open   tweets           nXfKaIIsTAGFc6Lk1CsKIw   2   2       4717            0      4.8mb          1.6mb
```
Pre complience so zadaniem :), zvacsil som pocet tweetov do 6000 spravil bulk tym istym sposobom.

GET `localhost:9200/_cat/indices?v`
```
health status index            uuid                   pri rep docs.count docs.deleted store.size pri.store.size
green  open   .geoip_databases Q33F6VbZQRWeJthpPVrMCw   1   1         42           22      103mb         51.5mb
green  open   tweets           nXfKaIIsTAGFc6Lk1CsKIw   2   2       5473            0      7.3mb          2.4mb
```

7. Experimenty s nodami. V tejto ulhe postupne odstanujem nody a vykonavam ten isty scenar
SCENAR
   1. BULK ADD - POST `localhost:9200/tweets/_bulk`
   ```json lines
   {"index" : {"_id" : "1266393217991421952"}}
   {"tweet_id":"1266393217991421952","content":"Very interesting.\\r\\n\\r\\nWhere is the Old Guard?\\r\\n\\r\\nEnjoying the show? \\r\\n\\r\\n#QAnon https://t.co/tbEIWHDzWM","happened_at":"2020-05-29T15:37:26+02:00","parent_id":null,"retweet_count":120,"favorite_count":0,"user":{"id":1246516732816175105,"screen_name":"WereAllQ","name":"WereAllMadHere🐾♟🕑🗝","description":"","followers_count":156,"friends_count":289,"statuses_count":295},"hashtags":["QAnon"]}
   {"index" : {"_id" : "1266393217152532480"}}
   {"tweet_id":"1266393217152532480","content":"Funny how Soros said in January about POTUS - \\"His problem is that the elections are still 10 months away, and in a [revolutionary situation], that's a lifetime\\" - then we had the virus and now obviously organized riots... \\r\\n\\r\\nJust saying. #QAnon https://t.co/9zBeETXLLB","happened_at":"2020-05-29T15:37:26+02:00","parent_id":null,"retweet_count":3885,"favorite_count":0,"user":{"id":1034826860520263686,"screen_name":"Looking4Truth17","name":"NavyBrat1017","description":"Love God, my family and my country! #PerspectiveMatters #MAGA #LoveAboveAll #AmericaTheFree #TrumpForAllAmericans #StrongerTogether #WWG1WGA","followers_count":2007,"friends_count":4955,"statuses_count":28720},"hashtags":["QAnon"]}
   {"index" : {"_id" : "1266393194301992960"}}
   {"tweet_id":"1266393194301992960","content":"Trump Jr. takes a NICE SHOT at Kathy Griffin! Check out this article I wrote for https://t.co/ZLWdm3YMMy!\\r\\n\\r\\nhttps://t.co/9Av8HerUwb\\r\\n\\r\\n#MAGA #Trump #Qanon #TWGRP #TheMighty200","happened_at":"2020-05-29T15:37:20+02:00","parent_id":null,"retweet_count":23,"favorite_count":0,"user":{"id":938152602935726081,"screen_name":"HLAurora63","name":"ALS😊BAM❤️BAM","description":null,"followers_count":null,"friends_count":null,"statuses_count":null},"hashtags":["MAGA", "Qanon"]}
   {"index" : {"_id" : "1266393175712763905"}}
   {"tweet_id":"1266393175712763905","content":"Barr just dropped the bomb!! Nailed it!!\\r\\n\\r\\nStopping advertisement of Child P0rn &amp; human trafficking. \\r\\n\\r\\n@Beer_Parade @SheepKnowMore @kate_awakening @anonforq @KarluskaP @cjtruth @BurnedSpy34 @RiQ_Grimes @mikebravodude @BardsFM \\r\\n\\r\\n#WWG1WGA #QAnon #QArmy #TheGreatAwakening https://t.co/kUN4H17nBc","happened_at":"2020-05-29T15:37:16+02:00","parent_id":null,"retweet_count":2982,"favorite_count":0,"user":{"id":3700623209,"screen_name":"mispats2u","name":"mispats","description":"God #1, 2nd Amen. Trump placed by God & answered prayer. Nothing is as it seems. Investigation=good&evil on both sides of aisle; FB-Gen.Flynn","followers_count":3980,"friends_count":4783,"statuses_count":58075},"hashtags":["QAnon", "WWG1WGA"]}
   {"index" : {"_id" : "1266393174328643584"}}
   {"tweet_id":"1266393174328643584","content":"Remember, President Trump declared a National State of Emergency. This gives him tremendous powers\\r\\nQ: Posse Comitatus Act-proscribes use of the Army or the Air Force to execute the law. \\r\\nMI in Control #TrustThePlan #Qanon\\r\\nhttps://t.co/gBqBmXPACm📁\\r\\nhttps://t.co/QRMQtWvLM3📁 https://t.co/uHoCZYW0X1","happened_at":"2020-05-29T15:37:15+02:00","parent_id":null,"retweet_count":491,"favorite_count":0,"user":{"id":1232791639078449153,"screen_name":"Trumpenator22","name":"Tumpanomics1","description":"I love the important things in life. God ,Family and Country 🔥🇺🇸✝️🔯🇺🇸❤️I am for...PRESIDENT TRUMP🇺🇸🇺🇸. FREE General Flynn ⭐️⭐️⭐️WWG1WGA🚫DM","followers_count":2874,"friends_count":2751,"statuses_count":29711},"hashtags":["Qanon"]}
   
   ```
   2. Document Retrieve - GET `localhost:9200/tweets/_doc/1266393217991421952`
   3. SEARCH Documents - POST `localhost:9200/tweets/_search`
   ```json
   {
   "query": {
       "match": {
         "content": "Interesting that the law"
       }
     }
   }
   ```
   ```json
   {
   "query": {
       "match": {
         "content": "Where is the Old Guard?"
       }
     }
   }
   ```   
   4. Bulk DELETE - POST `localhost:9200/tweets/_bulk`
   ```json lines
   {"delete" : {"_id" : "1266393217991421952"}}
   {"delete" : {"_id" : "1266393217152532480"}}
   {"delete" : {"_id" : "1266393194301992960"}}
   {"delete" : {"_id" : "1266393175712763905"}}
   {"delete" : {"_id" : "1266393174328643584"}}
   ```
Odstranime jeden node (`es03`). GET `localhost:9200/_cat/nodes?v`
```
ip         heap.percent ram.percent cpu load_1m load_5m load_15m node.role   master name
172.19.0.3           43          40   0    0.75    0.19     0.06 cdfhilmrstw *      es02
172.19.0.2           71          40   0    0.75    0.19     0.06 cdfhilmrstw -      es01
```
   SCENAR
   1. BULK ADD, RESPONSE
   ```json
   {
       "took": 386,
       "errors": true,
       "items": [
           {
               "index": {
                   "_index": "tweets",
                   "_type": "_doc",
                   "_id": "1266393217991421952",
                   "_version": 1,
                   "result": "created",
                   "_shards": {
                       "total": 3,
                       "successful": 2,
                       "failed": 0
                   },
                   "_seq_no": 18551,
                   "_primary_term": 3,
                   "status": 201
               }
           },
           {
               "index": {
                   "_index": "tweets",
                   "_type": "_doc",
                   "_id": "1266393217152532480",
                   "status": 400,
                   "error": {
                       "type": "mapper_parsing_exception",
                       "reason": "failed to parse",
                       "caused_by": {
                           "type": "i_o_exception",
                           "reason": "Unexpected character ('H' (code 72)): was expecting comma to separate Object entries\n at [Source: (ByteArrayInputStream); line: 1, column: 96]"
                       }
                   }
               }
           },
           {
               "index": {
                   "_index": "tweets",
                   "_type": "_doc",
                   "_id": "1266393194301992960",
                   "_version": 1,
                   "result": "created",
                   "_shards": {
                       "total": 3,
                       "successful": 2,
                       "failed": 0
                   },
                   "_seq_no": 17941,
                   "_primary_term": 4,
                   "status": 201
               }
           },
           {
               "index": {
                   "_index": "tweets",
                   "_type": "_doc",
                   "_id": "1266393175712763905",
                   "_version": 1,
                   "result": "created",
                   "_shards": {
                       "total": 3,
                       "successful": 2,
                       "failed": 0
                   },
                   "_seq_no": 17942,
                   "_primary_term": 4,
                   "status": 201
               }
           },
           {
               "index": {
                   "_index": "tweets",
                   "_type": "_doc",
                   "_id": "1266393174328643584",
                   "_version": 1,
                   "result": "created",
                   "_shards": {
                       "total": 3,
                       "successful": 2,
                       "failed": 0
                   },
                   "_seq_no": 17943,
                   "_primary_term": 4,
                   "status": 201
               }
           }
       ]
   }
   ```
   2. RETRIEVE DOCUMENT, RESPONCE
   ```json
   {
       "_index": "tweets",
       "_type": "_doc",
       "_id": "1266393217991421952",
       "_version": 1,
       "_seq_no": 18551,
       "_primary_term": 3,
       "found": true,
       "_source": {
           "tweet_id": "1266393217991421952",
           "content": "Very interesting.\\r\\n\\r\\nWhere is the \u0093Old Guard\u0094?\\r\\n\\r\\nEnjoying the show? \\r\\n\\r\\n#QAnon https://t.co/tbEIWHDzWM",
           "happened_at": "2020-05-29T15:37:26+02:00",
           "parent_id": null,
           "retweet_count": 120,
           "favorite_count": 0,
           "user": {
               "id": 1246516732816175105,
               "screen_name": "WereAllQ",
               "name": "We\u0092reAllMadHere🐾♟🕑🗝",
               "description": "",
               "followers_count": 156,
               "friends_count": 289,
               "statuses_count": 295
           },
           "hashtags": [
               "QAnon"
           ]
       }
   }
   ```
   3. SEARCH Documents 
      1. FROM 5k bulk import
      ```json
      {
         "took": 972,
             "timed_out": false,
             "_shards": {
                 "total": 2,
                 "successful": 2,
                 "skipped": 0,
                 "failed": 0
             },
             "hits": {
                 "total": {
                     "value": 98,
                     "relation": "eq"
                 },
                 "max_score": 10.537207,
                 "hits": [
                     {
                         "_index": "tweets",
                         "_type": "_doc",
                         "_id": "1260390932815347712",
                         "_score": 10.537207,
                         "_source": {
                             "tweet_id": "1260390932815347712",
                             "content": "Interesting that the law firm for so many PEDOWOOD royalty was cyber attacked....\\r\\n\\r\\n#q #qanon #WWG1GWAWORLDWIDE \\r\\n\\r\\nhttps://t.co/FAS3v9zcGZ",
                             "happened_at": "2020-05-13T02:06:29+02:00",
                             "parent_id": null,
                             "retweet_count": 767,
                             "favorite_count": 0,
                             "user": {
                                 "id": 2790529607,
                                 "screen_name": "truth9876",
                                 "name": "David Armstrong",
                                 "description": "",
                                 "followers_count": 2136,
                                 "friends_count": 3209,
                                 "statuses_count": 203234
                             },
                             "hashtags": [
                                 "qanon"
                             ]
                         }
                     },
      ```
      2. From fresh added docs
      ```json
      {
          "took": 4,
          "timed_out": false,
          "_shards": {
              "total": 2,
              "successful": 2,
              "skipped": 0,
              "failed": 0
          },
          "hits": {
              "total": {
                  "value": 101,
                  "relation": "eq"
              },
              "max_score": 13.022966,
              "hits": [
                  {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1266393217991421952",
                      "_score": 13.022966,
                      "_source": {
                          "tweet_id": "1266393217991421952",
                          "content": "Very interesting.\\r\\n\\r\\nWhere is the \u0093Old Guard\u0094?\\r\\n\\r\\nEnjoying the show? \\r\\n\\r\\n#QAnon https://t.co/tbEIWHDzWM",
                          "happened_at": "2020-05-29T15:37:26+02:00",
                          "parent_id": null,
                          "retweet_count": 120,
                          "favorite_count": 0,
                          "user": {
                              "id": 1246516732816175105,
                              "screen_name": "WereAllQ",
                              "name": "We\u0092reAllMadHere🐾♟🕑🗝",
                              "description": "",
                              "followers_count": 156,
                              "friends_count": 289,
                              "statuses_count": 295
                          },
                          "hashtags": [
                              "QAnon"
                          ]
                      }
                  },
                  {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1266073229736755201",
                      "_score": 12.650583,
                      "_source": {
                          "tweet_id": "1266073229736755201",
                          "content": "You are witnessing the systematic destruction of the OLD GUARD. Literally. Crest is gone. Buckingham Palace guards aren't there. All of the windows covered! It's going to be BIBLICAL. Another side of the pyramid has collapsed! Let's do the Vatican now. PANIC.\\r\\n#QAnon #WWG1GWA https://t.co/YKwY8NS9j3 https://t.co/3pubfJ2XIs",
                          "happened_at": "2020-05-28T18:25:55+02:00",
                          "parent_id": null,
                          "retweet_count": 484,
                          "favorite_count": 0,
                          "user": {
                              "id": 155651563,
                              "screen_name": "54Ange",
                              "name": "Von ⭐️⭐️⭐️",
                              "description": "‘we are exposing the depravity, dishonesty and sickness of the corrupt Wash establishment w your help, we are going to complete the mission & drain the swamp ‘",
                              "followers_count": 2235,
                              "friends_count": 2082,
                              "statuses_count": 245042
                          },
                          "hashtags": [
                              "QAnon"
                          ]
                      }
                  },
                  {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1266050149991813120",
                      "_score": 11.999307,
                      "_source": {
                          "tweet_id": "1266050149991813120",
                          "content": "You are witnessing the systematic destruction of the OLD GUARD. Literally. Crest is gone. Buckingham Palace guards aren't there. All of the windows covered! It's going to be BIBLICAL. Another side of the pyramid has collapsed! Let's do the Vatican now. PANIC.\\r\\n#QAnon #WWG1GWA https://t.co/YKwY8NS9j3 https://t.co/3pubfJ2XIs",
                          "happened_at": "2020-05-28T16:54:12+02:00",
                          "parent_id": null,
                          "retweet_count": 484,
                          "favorite_count": 0,
                          "user": {
                              "id": 114487659,
                              "screen_name": "carlthesolarguy",
                              "name": "Carl Glick",
                              "description": "",
                              "followers_count": 460,
                              "friends_count": 540,
                              "statuses_count": 2392
                          },
                          "hashtags": [
                              "QAnon"
                          ]
                      }
                  },
                  {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1266053865482436608",
                      "_score": 11.999307,
                      "_source": {
                          "tweet_id": "1266053865482436608",
                          "content": "You are witnessing the systematic destruction of the OLD GUARD. Literally. Crest is gone. Buckingham Palace guards aren't there. All of the windows covered! It's going to be BIBLICAL. Another side of the pyramid has collapsed! Let's do the Vatican now. PANIC.\\r\\n#QAnon #WWG1GWA https://t.co/YKwY8NS9j3 https://t.co/3pubfJ2XIs",
                          "happened_at": "2020-05-28T17:08:58+02:00",
                          "parent_id": null,
                          "retweet_count": 484,
                          "favorite_count": 0,
                          "user": {
                              "id": 1161233947776495622,
                              "screen_name": "DanishWwg1wga",
                              "name": "DanishPatriotWWG1WGA⭐⭐⭐",
                              "description": "",
                              "followers_count": 377,
                              "friends_count": 556,
                              "statuses_count": 995
                          },
                          "hashtags": [
                              "QAnon"
                          ]
                      }
                  },
                  {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1266066645430210560",
                      "_score": 11.999307,
                      "_source": {
                          "tweet_id": "1266066645430210560",
                          "content": "You are witnessing the systematic destruction of the OLD GUARD. Literally. Crest is gone. Buckingham Palace guards aren't there. All of the windows covered! It's going to be BIBLICAL. Another side of the pyramid has collapsed! Let's do the Vatican now. PANIC.\\r\\n#QAnon #WWG1GWA https://t.co/YKwY8NS9j3 https://t.co/3pubfJ2XIs",
                          "happened_at": "2020-05-28T17:59:45+02:00",
                          "parent_id": null,
                          "retweet_count": 484,
                          "favorite_count": 0,
                          "user": {
                              "id": 35500378,
                              "screen_name": "Mindy4110",
                              "name": "Former Democrat Sue",
                              "description": "Believe in Trump. Beyond Embaressed I was EVER a Dem. Trust in God!, Pro-life. Silent majority. Boycott Power, Prayer Power, #2A #1A, MAGA",
                              "followers_count": 8919,
                              "friends_count": 9669,
                              "statuses_count": 177100
                          },
                          "hashtags": [
                              "QAnon"
                          ]
                      }
                  },
                  {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1249993881317453825",
                      "_score": 9.930998,
                      "_source": {
                          "tweet_id": "1249993881317453825",
                          "content": "New #QAnon shows the old meme of \u0093when do the trials begin\u0094 without John Brennan. Where is he? Is he the first of 6? Is that why the file name of the meme says 5_4_3_2_1_? https://t.co/lav67Up2P3",
                          "happened_at": "2020-04-14T09:32:19+02:00",
                          "parent_id": null,
                          "retweet_count": 108,
                          "favorite_count": 0,
                          "user": {
                              "id": 390055135,
                              "screen_name": "QAnonFrFight",
                              "name": "QAnon France is fighting NWO !👊🏼🇫🇷🇺🇸",
                              "description": "",
                              "followers_count": 1122,
                              "friends_count": 1324,
                              "statuses_count": 4173
                          },
                          "hashtags": [
                              "QAnon"
                          ]
                      }
                  },
                  {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1259271368639762440",
                      "_score": 9.779989,
                      "_source": {
                          "tweet_id": "1259271368639762440",
                          "content": "Awesome thread by @BurnedSpy34 the destruction of the old guard is taking place-this isn\u0092t just about rounding up players in the global crime syndicate-it\u0092s about removing the power structures so it can never come back-patience! Thank you @POTUS @thejointstaff #Q #Qanon https://t.co/kpByFw0niw",
                          "happened_at": "2020-05-09T23:57:45+02:00",
                          "parent_id": null,
                          "retweet_count": 7,
                          "favorite_count": 7,
                          "user": {
                              "id": 1029522668,
                              "screen_name": "truthseekerd",
                              "name": "Donna ⭐️⭐️⭐️",
                              "description": "Love USA,💯President #Trump #GenFlynn military men&women #NRA-it’s our country not politician’s💕my husband/kids/horses/Truth/God/prayer/#Qanon",
                              "followers_count": 7027,
                              "friends_count": 7638,
                              "statuses_count": 80360
                          },
                          "hashtags": [
                              "Qanon"
                          ]
                      }
                  },
                  {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1251900017494896640",
                      "_score": 6.9701447,
                      "_source": {
                          "tweet_id": "1251900017494896640",
                          "content": "Trump retweeted this old EverGreen Tweet today. #QANON https://t.co/ZgbzTlQiU9",
                          "happened_at": "2020-04-19T15:46:38+02:00",
                          "parent_id": null,
                          "retweet_count": 28,
                          "favorite_count": 113,
                          "user": {
                              "id": 1060325652698710025,
                              "screen_name": "An0n661",
                              "name": "An0n661",
                              "description": "TRUST THE PLAN",
                              "followers_count": 45726,
                              "friends_count": 397,
                              "statuses_count": 12374
                          },
                          "hashtags": [
                              "QANON"
                          ]
                      }
                  },
                  {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1256010974668247040",
                      "_score": 6.7132583,
                      "_source": {
                          "tweet_id": "1256010974668247040",
                          "content": "A little old but definitely seems probable. #qanon #WWG1WGAWORLDWIDE #Adrenochrome #WWG1WGA https://t.co/9aFJSrj6JH",
                          "happened_at": "2020-05-01T00:02:06+02:00",
                          "parent_id": null,
                          "retweet_count": 1,
                          "favorite_count": 2,
                          "user": {
                              "id": 40567694,
                              "screen_name": "qtipslovedeepst",
                              "name": "-z- truths",
                              "description": "",
                              "followers_count": 70,
                              "friends_count": 18,
                              "statuses_count": 93
                          },
                          "hashtags": [
                              "qanon",
                              "WWG1WGA"
                          ]
                      }
                  },
                  {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1254568213179822084",
                      "_score": 6.4817667,
                      "_source": {
                          "tweet_id": "1254568213179822084",
                          "content": "Everyone remembers where they were on 9/11 but I want to know where they were post 9/11 when the patriot act was passed #Qanon https://t.co/DNzmaR1NYb",
                          "happened_at": "2020-04-27T00:29:05+02:00",
                          "parent_id": null,
                          "retweet_count": 72,
                          "favorite_count": 0,
                          "user": {
                              "id": 2762482737,
                              "screen_name": "laneyd777",
                              "name": "Lane",
                              "description": "Proud American, Marine Mom.",
                              "followers_count": 800,
                              "friends_count": 1796,
                              "statuses_count": 5722
                          },
                          "hashtags": [
                              "Qanon"
                          ]
                      }
                  }
              ]
          }
      }
      ```
   4. BULK DELETE
      ```json
      {
          "took": 36,
          "errors": false,
          "items": [
              {
                  "delete": {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1266393217991421952",
                      "_version": 2,
                      "result": "deleted",
                      "_shards": {
                          "total": 3,
                          "successful": 2,
                          "failed": 0
                      },
                      "_seq_no": 18552,
                      "_primary_term": 3,
                      "status": 200
                  }
              },
              {
                  "delete": {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1266393217152532480",
                      "_version": 1,
                      "result": "not_found",
                      "_shards": {
                          "total": 3,
                          "successful": 2,
                          "failed": 0
                      },
                      "_seq_no": 18553,
                      "_primary_term": 3,
                      "status": 404
                  }
              },
              {
                  "delete": {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1266393194301992960",
                      "_version": 2,
                      "result": "deleted",
                      "_shards": {
                          "total": 3,
                          "successful": 2,
                          "failed": 0
                      },
                      "_seq_no": 17944,
                      "_primary_term": 4,
                      "status": 200
                  }
              },
              {
                  "delete": {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1266393175712763905",
                      "_version": 2,
                      "result": "deleted",
                      "_shards": {
                          "total": 3,
                          "successful": 2,
                          "failed": 0
                      },
                      "_seq_no": 17945,
                      "_primary_term": 4,
                      "status": 200
                  }
              },
              {
                  "delete": {
                      "_index": "tweets",
                      "_type": "_doc",
                      "_id": "1266393174328643584",
                      "_version": 2,
                      "result": "deleted",
                      "_shards": {
                          "total": 3,
                          "successful": 2,
                          "failed": 0
                      },
                      "_seq_no": 17946,
                      "_primary_term": 4,
                      "status": 200
                  }
              }
          ]
      }
      ```
Vyzera ze vsetko funguje tak ako ma aj na 2 nodach. Odstranime este jeden  non-master node - `es02`.
   
   SCENAR
1. BULK ADD, RESPONSE - bezi dost dlho. Cluster_blocker_exception znamena ze cluster iba v read only mode, preto ze
nema dost pamate na zapisovanie dalsich udajov.
```json
{
    "error": {
        "root_cause": [
            {
                "type": "cluster_block_exception",
                "reason": "blocked by: [SERVICE_UNAVAILABLE/2/no master];"
            }
        ],
        "type": "cluster_block_exception",
        "reason": "blocked by: [SERVICE_UNAVAILABLE/2/no master];"
    },
    "status": 503
}
```
2. Document retrieve funguje bez problemov. GET `localhost:9200/tweets/_doc/1256313172593688576`
```json
{
    "_index": "tweets",
    "_type": "_doc",
    "_id": "1256313172593688576",
    "_version": 1,
    "_seq_no": 15763,
    "_primary_term": 3,
    "found": true,
    "_source": {
        "tweet_id": "1256313172593688576",
        "content": "Durham is coming.\\r\\nShare far and wide, Anons. We are the news now!\\r\\n#Q #Qanon #Qarmy #PainComing #WWG1WGA #SHIFTY #CrossfireRazor #CrossfireHurricane #CrossfireTyphoon #Durham #AGBarr https://t.co/WANy3mpULB",
        "happened_at": "2020-05-01T20:02:56+02:00",
        "parent_id": null,
        "retweet_count": 26,
        "favorite_count": 0,
        "user": {
            "id": 823616163624222720,
            "screen_name": "Woodman775",
            "name": "Woodman",
            "description": "#CONSTITUTION #MAGA #2A #Conservative #Patriot #Veteran #KAG2020",
            "followers_count": 4603,
            "friends_count": 4868,
            "statuses_count": 16742
        },
        "hashtags": [
            "WWG1WGA",
            "Qanon"
        ]
    }
}
```
3. Document search funguje bez problemov. 1. query
```json
{
    "took": 38,
    "timed_out": false,
    "_shards": {
        "total": 2,
        "successful": 2,
        "skipped": 0,
        "failed": 0
    },
    "hits": {
        "total": {
            "value": 96,
            "relation": "eq"
        },
        "max_score": 10.537207,
       "hits": [
            {
                "_index": "tweets",
                "_type": "_doc",
                "_id": "1260390932815347712",
                "_score": 10.537207,
                "_source": {
                    "tweet_id": "1260390932815347712",
                    "content": "Interesting that the law firm for so many PEDOWOOD royalty was cyber attacked....\\r\\n\\r\\n#q #qanon #WWG1GWAWORLDWIDE \\r\\n\\r\\nhttps://t.co/FAS3v9zcGZ",
                    "happened_at": "2020-05-13T02:06:29+02:00",
                    "parent_id": null,
                    "retweet_count": 767,
                    "favorite_count": 0,
                    "user": {
                        "id": 2790529607,
                        "screen_name": "truth9876",
                        "name": "David Armstrong",
                        "description": "",
                        "followers_count": 2136,
                        "friends_count": 3209,
                        "statuses_count": 203234
                    },
                    "hashtags": [
                        "qanon"
                    ]
                }
            },

```
4. Document DELETE `localhost:9200/tweets/_doc/1256313172593688576` - nefunuguje, taky isty
exception ako pri BULK ADD.
```json
{
    "error": {
        "root_cause": [
            {
                "type": "cluster_block_exception",
                "reason": "blocked by: [SERVICE_UNAVAILABLE/2/no master];"
            }
        ],
        "type": "cluster_block_exception",
        "reason": "blocked by: [SERVICE_UNAVAILABLE/2/no master];"
    },
    "status": 503
}
```


Pridame dva nody spat. Vieme spravit single node cluster. pomocou dalsich uprav v docker-compose subore.
```yaml
environment:
      - network.host=0.0.0.0
      - discovery.type=single-node
```
Ale som to nespravil preto, nevieme z noda ktory bol castou vacsieho clustra spravit single cluster,
preto ze moze dojst k strate udajov. (co nechceme). Aby spravit single-node cluster potrebujeme
zmazat vsetky data a potom spustin nanovo s updatnutym configom.

8. Upravujte pocet retweetov pre vami vybrany tweet. GET `localhost:9200/tweets/_doc/1260323088631246850` mame tri nody.
```json
{
    "_index": "tweets",
    "_type": "_doc",
    "_id": "1260323088631246850",
    "_version": 1,
    "_seq_no": 18532,
    "_primary_term": 3,
    "found": true,
    "_source": {
        "tweet_id": "1260323088631246850",
        "content": "Explain to me why the media takes their masks off when they think the cameras are off? Is it all for show? #fakenews #LamestreamMedia looks like the rules only apply to us peasants. #obamagate #qanon https://t.co/rlET581ytJ",
        "happened_at": "2020-05-12T21:36:54+02:00",
        "parent_id": null,
        "retweet_count": 28189,
        "favorite_count": 0,
        "user": {
            "id": 1242562207097008130,
            "screen_name": "Cj37056059",
            "name": "Cj",
            "description": "",
            "followers_count": 18,
            "friends_count": 112,
            "statuses_count": 795
        },
        "hashtags": [
            "qanon"
        ]
    }
}
```

Pri POST `localhost:9200/tweets/_update/1260323088631246850`
```json
{
	"script":{
		"lang": "painless",
		"source":"ctx._source.retweet_count+=1"
	}
}
```
RESPONSE:
```json
{
    "_index": "tweets",
    "_type": "_doc",
    "_id": "1260323088631246850",
    "_version": 2,
    "result": "updated",
    "_shards": {
        "total": 3,
        "successful": 3,
        "failed": 0
    },
    "_seq_no": 18554,
    "_primary_term": 5
}
```
Vdimime ze `_seq_no` stupol (o 2 preto ze som 2krat updatol), `_primary_term` bol na 3 sharde - stal 5 sharde.
Teraz odstranime node `es03` skusime updatnut este raz.
RESPONSE:
```json
{
    "_index": "tweets",
    "_type": "_doc",
    "_id": "1260323088631246850",
    "_version": 3,
    "result": "updated",
    "_shards": {
        "total": 3,
        "successful": 2,
        "failed": 0
    },
    "_seq_no": 18555,
    "_primary_term": 5
}
```
Vidime ze `_seq_no` este raz stupol, `_primary_term` sa zostal ten isty 5. Updatlo sa iba dva shardy z troch existujucich.
Teraz zapnem node `es03` a dame query este raz.
RESPONSE:
```json
{
    "_index": "tweets",
    "_type": "_doc",
    "_id": "1260323088631246850",
    "_version": 4,
    "result": "updated",
    "_shards": {
        "total": 3,
        "successful": 2,
        "failed": 0
    },
    "_seq_no": 18556,
    "_primary_term": 5
}
```
Vidime ze `_seq_no` este raz stupol, a updatol sa document na 5 sharde (`_primary_term`). 
Updatlo tak isto sa iba dva shardy z troch existujucich.

9. Zruste Repliky a Import vsetky tweety. PUT `localhost:9200/tweets/_settings`
```json
{
	"index" : {
		"number_of_replicas":0
	}
}
```
Zapisem vsetky tweety do text suboru, a pridan `\n` pomocou python scriptu.


