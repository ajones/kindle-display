Scrape integration (UI): resource https://api.bart.gov/api/etd.aspx?cmd=etd&orig=WCRK&key=MW9S-E7SL-26DU-VV8V (BART public key)
Sensor "BART Walnut Creek next to SFO": select `etd estimate:has(> direction:-soup-contains("South")) > minutes`, index 0,
value_template `{{ 0 if value == 'Leaving' else value | int(0) }}`, unit min.
