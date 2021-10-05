CREATE TYPE themes AS ENUM(
		'deep_state',
		'qanon',
		'new_world_order',
		'escaped_chinees_virus',
		'global_warming_hoax',
		'covid19_microchipping',
		'covid19_preaded_5g',
		'moon_landing_fake',
		'911_inside_job',
		'pizzagate',
		'chem_trails',
		'flat_earth',
		'illuminati',
		'reptilians'
)
CREATE TABLE conspiracy_themes(
	theme_id INT GENERATED ALWAYS AS IDENTITY,
	theme_name themes,
	PRIMARY KEY(theme_id)
)

INSERT INTO conspiracy_themes (theme_name)
VALUES ('deep_state'),
		('qanon'),
		('new_world_order'),
		('escaped_chinees_virus'),
		('global_warming_hoax'),
		('covid19_microchipping'),
		('covid19_preaded_5g'),
		('moon_landing_fake'),
		('911_inside_job'),
		('pizzagate'),
		('chem_trails'),
		('flat_earth'),
		('illuminati'),
		('reptilians')


CREATE Table conspiracy_hashtags (
	hashtag_id INT GENERATED ALWAYS AS IDENTITY,
	hashtag_value varchar(255),
	theme_id INT,
	CONSTRAINT fk_theme
		FOREIGN KEY(theme_id)
		REFERENCES conspiracy_themes(theme_id)
);


INSERT INTO conspiracy_hashtags (hashtag_value, theme_id)
VALUES ('DeepstateVirus', 4),
	   ('DeepStateVaccine', 4),
	   ('DeepStateFauci', 4),
	   ('MAGA', 5),
	   ('WWG1WGA', 5),
	   ('QAnon', 5),
	   ('Agenda21',6),
	   ('CCPVirus', 7),
	   ('ChinaLiedPeopleDied', 7),
	   ('GlobalWarmingHoax', 8),
	   ('ClimateChangeHoax', 8),
	   ('SorosVirus', 9),
	   ('BillGAtes', 9),
	   ('5GCoronavirus', 10),
	   ('MoonLandingHoax', 11),
	   ('moonhoax', 11),
	   ('911truth ', 12),
	   ('911insidejob', 12),
	   ('pizzaGateIsReal', 13),
	   ('PedoGateIsReal', 13),
	   ('Chemtrails', 14),
	   ('flatEarth', 15),
	   ('illuminati', 16),
	   ('reptilians', 17)