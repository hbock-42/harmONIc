// GENERATED FILE — do not edit.
// Run `dart run tool/gen_data.dart` after editing lib/data/oni_data.json.

const String oniDataJson = r"""
{
  "dataVersion": "0.1.0",
  "gameBuild": "base game + Spaced Out!",
  "items": [
    {
      "id": "power",
      "name": "Power",
      "category": "power"
    },
    {
      "id": "heat",
      "name": "Heat",
      "category": "heat"
    },
    {
      "id": "water",
      "name": "Water",
      "category": "liquid"
    },
    {
      "id": "polluted_water",
      "name": "Polluted Water",
      "category": "liquid"
    },
    {
      "id": "brine",
      "name": "Brine",
      "category": "liquid"
    },
    {
      "id": "salt_water",
      "name": "Salt Water",
      "category": "liquid"
    },
    {
      "id": "crude_oil",
      "name": "Crude Oil",
      "category": "liquid"
    },
    {
      "id": "petroleum",
      "name": "Petroleum",
      "category": "liquid"
    },
    {
      "id": "ethanol",
      "name": "Ethanol",
      "category": "liquid"
    },
    {
      "id": "liquid_oxygen",
      "name": "Liquid Oxygen",
      "category": "liquid"
    },
    {
      "id": "oxygen",
      "name": "Oxygen",
      "category": "gas"
    },
    {
      "id": "polluted_oxygen",
      "name": "Polluted Oxygen",
      "category": "gas"
    },
    {
      "id": "hydrogen",
      "name": "Hydrogen",
      "category": "gas"
    },
    {
      "id": "carbon_dioxide",
      "name": "Carbon Dioxide",
      "category": "gas"
    },
    {
      "id": "natural_gas",
      "name": "Natural Gas",
      "category": "gas"
    },
    {
      "id": "chlorine",
      "name": "Chlorine",
      "category": "gas"
    },
    {
      "id": "steam",
      "name": "Steam",
      "category": "gas"
    },
    {
      "id": "algae",
      "name": "Algae",
      "category": "solid"
    },
    {
      "id": "slime",
      "name": "Slime",
      "category": "solid"
    },
    {
      "id": "dirt",
      "name": "Dirt",
      "category": "solid"
    },
    {
      "id": "polluted_dirt",
      "name": "Polluted Dirt",
      "category": "solid"
    },
    {
      "id": "sand",
      "name": "Sand",
      "category": "solid"
    },
    {
      "id": "clay",
      "name": "Clay",
      "category": "solid"
    },
    {
      "id": "salt",
      "name": "Salt",
      "category": "solid"
    },
    {
      "id": "coal",
      "name": "Coal",
      "category": "solid"
    },
    {
      "id": "refined_carbon",
      "name": "Refined Carbon",
      "category": "solid"
    },
    {
      "id": "oxylite",
      "name": "Oxylite",
      "category": "solid"
    },
    {
      "id": "rust",
      "name": "Rust",
      "category": "solid"
    },
    {
      "id": "iron_ore",
      "name": "Iron Ore",
      "category": "solid"
    },
    {
      "id": "iron",
      "name": "Iron",
      "category": "solid"
    },
    {
      "id": "copper_ore",
      "name": "Copper Ore",
      "category": "solid"
    },
    {
      "id": "copper",
      "name": "Copper",
      "category": "solid"
    },
    {
      "id": "gold_amalgam",
      "name": "Gold Amalgam",
      "category": "solid"
    },
    {
      "id": "gold",
      "name": "Gold",
      "category": "solid"
    },
    {
      "id": "sedimentary_rock",
      "name": "Sedimentary Rock",
      "category": "solid"
    },
    {
      "id": "lumber",
      "name": "Lumber",
      "category": "solid"
    },
    {
      "id": "plastic",
      "name": "Plastic",
      "category": "solid"
    },
    {
      "id": "calories",
      "name": "Calories",
      "category": "other"
    },
    {
      "id": "duplicant",
      "name": "Duplicant",
      "category": "entity"
    }
  ],
  "processes": [
    {
      "id": "electrolyzer",
      "name": "Electrolyzer",
      "kind": "building",
      "buildingId": "electrolyzer",
      "powerWatts": 120,
      "heatKdtuPerSecond": 1.25,
      "footprintWidth": 2,
      "footprintHeight": 2,
      "tags": [
        "oxygen",
        "verified"
      ],
      "ports": [
        {
          "item": "water",
          "direction": "input",
          "rate": 1000
        },
        {
          "item": "oxygen",
          "direction": "output",
          "rate": 888,
          "temperatureC": 70
        },
        {
          "item": "hydrogen",
          "direction": "output",
          "rate": 112,
          "temperatureC": 70
        }
      ]
    },
    {
      "id": "algae_terrarium",
      "name": "Algae Terrarium",
      "kind": "building",
      "buildingId": "algae_terrarium",
      "footprintWidth": 2,
      "footprintHeight": 2,
      "tags": [
        "oxygen",
        "verified"
      ],
      "ports": [
        {
          "item": "water",
          "direction": "input",
          "rate": 300
        },
        {
          "item": "algae",
          "direction": "input",
          "rate": 30
        },
        {
          "item": "carbon_dioxide",
          "direction": "input",
          "rate": 0.33333
        },
        {
          "item": "oxygen",
          "direction": "output",
          "rate": 40,
          "temperatureC": 30
        },
        {
          "item": "polluted_water",
          "direction": "output",
          "rate": 290.33,
          "temperatureC": 30
        }
      ]
    },
    {
      "id": "algae_distiller",
      "name": "Algae Distiller",
      "kind": "building",
      "buildingId": "algae_distiller",
      "powerWatts": 120,
      "heatKdtuPerSecond": 1.5,
      "footprintWidth": 3,
      "footprintHeight": 3,
      "tags": [
        "oxygen",
        "verified"
      ],
      "ports": [
        {
          "item": "slime",
          "direction": "input",
          "rate": 600
        },
        {
          "item": "algae",
          "direction": "output",
          "rate": 200,
          "temperatureC": 30
        },
        {
          "item": "polluted_water",
          "direction": "output",
          "rate": 400,
          "temperatureC": 30
        }
      ]
    },
    {
      "id": "deodorizer",
      "name": "Deodorizer",
      "kind": "building",
      "buildingId": "deodorizer",
      "powerWatts": 5,
      "footprintWidth": 1,
      "footprintHeight": 2,
      "tags": [
        "oxygen",
        "verified"
      ],
      "ports": [
        {
          "item": "polluted_oxygen",
          "direction": "input",
          "rate": 100
        },
        {
          "item": "sand",
          "direction": "input",
          "rate": 133.33
        },
        {
          "item": "oxygen",
          "direction": "output",
          "rate": 90
        },
        {
          "item": "clay",
          "direction": "output",
          "rate": 143.33
        }
      ],
      "heatKdtuPerSecond": 0.625
    },
    {
      "id": "rust_deoxidizer",
      "name": "Rust Deoxidizer",
      "kind": "building",
      "buildingId": "rust_deoxidizer",
      "powerWatts": 60,
      "heatKdtuPerSecond": 1.125,
      "footprintWidth": 3,
      "footprintHeight": 3,
      "tags": [
        "oxygen",
        "verified"
      ],
      "ports": [
        {
          "item": "rust",
          "direction": "input",
          "rate": 750
        },
        {
          "item": "salt",
          "direction": "input",
          "rate": 250
        },
        {
          "item": "oxygen",
          "direction": "output",
          "rate": 570,
          "temperatureC": 75
        },
        {
          "item": "chlorine",
          "direction": "output",
          "rate": 30,
          "temperatureC": 75
        },
        {
          "item": "iron_ore",
          "direction": "output",
          "rate": 400,
          "temperatureC": 75
        }
      ]
    },
    {
      "id": "oxylite_refinery",
      "name": "Oxylite Refinery",
      "kind": "building",
      "buildingId": "oxylite_refinery",
      "powerWatts": 1200,
      "heatKdtuPerSecond": 12,
      "dupeLabourSecondsPerCycle": 0,
      "footprintWidth": 3,
      "footprintHeight": 3,
      "tags": [
        "oxygen",
        "verified"
      ],
      "ports": [
        {
          "item": "oxygen",
          "direction": "input",
          "rate": 600
        },
        {
          "item": "gold",
          "direction": "input",
          "rate": 3
        },
        {
          "item": "oxylite",
          "direction": "output",
          "rate": 600
        }
      ]
    },
    {
      "id": "water_sieve",
      "name": "Water Sieve",
      "kind": "building",
      "buildingId": "water_sieve",
      "powerWatts": 120,
      "footprintWidth": 2,
      "footprintHeight": 3,
      "tags": [
        "liquid",
        "verified"
      ],
      "ports": [
        {
          "item": "polluted_water",
          "direction": "input",
          "rate": 5000
        },
        {
          "item": "sand",
          "direction": "input",
          "rate": 1000
        },
        {
          "item": "water",
          "direction": "output",
          "rate": 5000
        },
        {
          "item": "polluted_dirt",
          "direction": "output",
          "rate": 200
        }
      ],
      "heatKdtuPerSecond": 4
    },
    {
      "id": "carbon_skimmer",
      "name": "Carbon Skimmer",
      "kind": "building",
      "buildingId": "carbon_skimmer",
      "powerWatts": 120,
      "footprintWidth": 2,
      "footprintHeight": 3,
      "tags": [
        "gas",
        "verified"
      ],
      "ports": [
        {
          "item": "water",
          "direction": "input",
          "rate": 1000
        },
        {
          "item": "carbon_dioxide",
          "direction": "input",
          "rate": 300
        },
        {
          "item": "polluted_water",
          "direction": "output",
          "rate": 1000
        }
      ],
      "heatKdtuPerSecond": 1
    },
    {
      "id": "desalinator_brine",
      "name": "Desalinator (Brine)",
      "kind": "building",
      "buildingId": "desalinator",
      "powerWatts": 480,
      "heatKdtuPerSecond": 8,
      "footprintWidth": 3,
      "footprintHeight": 3,
      "tags": [
        "liquid",
        "verified"
      ],
      "ports": [
        {
          "item": "brine",
          "direction": "input",
          "rate": 5000
        },
        {
          "item": "water",
          "direction": "output",
          "rate": 3500
        },
        {
          "item": "salt",
          "direction": "output",
          "rate": 1500
        }
      ]
    },
    {
      "id": "oil_refinery",
      "name": "Oil Refinery",
      "kind": "building",
      "buildingId": "oil_refinery",
      "powerWatts": 480,
      "heatKdtuPerSecond": 10,
      "dupeLabourSecondsPerCycle": 600,
      "footprintWidth": 3,
      "footprintHeight": 4,
      "tags": [
        "oil",
        "verified"
      ],
      "ports": [
        {
          "item": "crude_oil",
          "direction": "input",
          "rate": 10000
        },
        {
          "item": "petroleum",
          "direction": "output",
          "rate": 5000,
          "temperatureC": 75
        },
        {
          "item": "natural_gas",
          "direction": "output",
          "rate": 90,
          "temperatureC": 75
        }
      ]
    },
    {
      "id": "polymer_press",
      "name": "Polymer Press",
      "kind": "building",
      "buildingId": "polymer_press",
      "powerWatts": 240,
      "heatKdtuPerSecond": 32.5,
      "footprintWidth": 3,
      "footprintHeight": 3,
      "tags": [
        "oil",
        "verified"
      ],
      "ports": [
        {
          "item": "petroleum",
          "direction": "input",
          "rate": 833.33
        },
        {
          "item": "plastic",
          "direction": "output",
          "rate": 500,
          "temperatureC": 75
        },
        {
          "item": "steam",
          "direction": "output",
          "rate": 8.33,
          "temperatureC": 200
        },
        {
          "item": "carbon_dioxide",
          "direction": "output",
          "rate": 8.33,
          "temperatureC": 150
        }
      ]
    },
    {
      "id": "ethanol_distiller",
      "name": "Ethanol Distiller",
      "kind": "building",
      "buildingId": "ethanol_distiller",
      "powerWatts": 240,
      "heatKdtuPerSecond": 4.5,
      "footprintWidth": 3,
      "footprintHeight": 3,
      "tags": [
        "farming",
        "verified"
      ],
      "ports": [
        {
          "item": "lumber",
          "direction": "input",
          "rate": 1000
        },
        {
          "item": "ethanol",
          "direction": "output",
          "rate": 500,
          "temperatureC": 73.4
        },
        {
          "item": "polluted_dirt",
          "direction": "output",
          "rate": 333.33,
          "temperatureC": 93.4
        },
        {
          "item": "carbon_dioxide",
          "direction": "output",
          "rate": 166.67,
          "temperatureC": 93.4
        }
      ]
    },
    {
      "id": "coal_generator",
      "name": "Coal Generator",
      "kind": "building",
      "buildingId": "coal_generator",
      "powerWatts": -600,
      "heatKdtuPerSecond": 9,
      "footprintWidth": 4,
      "footprintHeight": 3,
      "tags": [
        "power",
        "verified"
      ],
      "ports": [
        {
          "item": "coal",
          "direction": "input",
          "rate": 1000
        },
        {
          "item": "carbon_dioxide",
          "direction": "output",
          "rate": 20
        }
      ]
    },
    {
      "id": "hydrogen_generator",
      "name": "Hydrogen Generator",
      "kind": "building",
      "buildingId": "hydrogen_generator",
      "powerWatts": -800,
      "heatKdtuPerSecond": 4,
      "footprintWidth": 2,
      "footprintHeight": 3,
      "tags": [
        "power",
        "verified"
      ],
      "ports": [
        {
          "item": "hydrogen",
          "direction": "input",
          "rate": 100
        }
      ]
    },
    {
      "id": "natural_gas_generator",
      "name": "Natural Gas Generator",
      "kind": "building",
      "buildingId": "natural_gas_generator",
      "powerWatts": -800,
      "heatKdtuPerSecond": 10,
      "footprintWidth": 4,
      "footprintHeight": 3,
      "tags": [
        "power",
        "verified"
      ],
      "ports": [
        {
          "item": "natural_gas",
          "direction": "input",
          "rate": 90
        },
        {
          "item": "carbon_dioxide",
          "direction": "output",
          "rate": 22.5
        },
        {
          "item": "polluted_water",
          "direction": "output",
          "rate": 67.5
        }
      ]
    },
    {
      "id": "petroleum_generator",
      "name": "Petroleum Generator",
      "kind": "building",
      "buildingId": "petroleum_generator",
      "powerWatts": -2000,
      "heatKdtuPerSecond": 20,
      "footprintWidth": 4,
      "footprintHeight": 3,
      "tags": [
        "power",
        "verified"
      ],
      "ports": [
        {
          "item": "petroleum",
          "direction": "input",
          "rate": 2000
        },
        {
          "item": "carbon_dioxide",
          "direction": "output",
          "rate": 500
        },
        {
          "item": "polluted_water",
          "direction": "output",
          "rate": 750
        }
      ]
    },
    {
      "id": "metal_refinery_iron",
      "name": "Metal Refinery (Iron)",
      "kind": "building",
      "buildingId": "metal_refinery",
      "powerWatts": 1200,
      "dupeLabourSecondsPerCycle": 600,
      "footprintWidth": 5,
      "footprintHeight": 3,
      "tags": [
        "refining",
        "verified"
      ],
      "ports": [
        {
          "item": "iron_ore",
          "direction": "input",
          "rate": 2500
        },
        {
          "id": "coolant_in",
          "item": "water",
          "direction": "input",
          "rate": 10000
        },
        {
          "item": "iron",
          "direction": "output",
          "rate": 2500,
          "temperatureC": 40
        },
        {
          "id": "coolant_out",
          "item": "water",
          "direction": "output",
          "rate": 10000
        }
      ],
      "heatKdtuPerSecond": 16,
      "description": "Batch building: 100 kg per 40 s operation. The coolant loop is the same liquid in and out, only hotter — wire it back on itself."
    },
    {
      "id": "rock_crusher_sand",
      "name": "Rock Crusher (Sand)",
      "kind": "building",
      "buildingId": "rock_crusher",
      "powerWatts": 240,
      "dupeLabourSecondsPerCycle": 600,
      "footprintWidth": 3,
      "footprintHeight": 3,
      "tags": [
        "refining",
        "verified"
      ],
      "ports": [
        {
          "item": "sedimentary_rock",
          "direction": "input",
          "rate": 2500
        },
        {
          "item": "sand",
          "direction": "output",
          "rate": 2500
        }
      ],
      "heatKdtuPerSecond": 16,
      "description": "Batch building: 100 kg per 40 s operation. Sedimentary rock crushes 1:1 into sand."
    },
    {
      "id": "duplicant",
      "name": "Duplicant",
      "kind": "duplicant",
      "tags": [
        "colony",
        "verified"
      ],
      "ports": [
        {
          "item": "oxygen",
          "direction": "input",
          "rate": 100
        },
        {
          "item": "calories",
          "direction": "input",
          "rate": 1.6667
        },
        {
          "item": "carbon_dioxide",
          "direction": "output",
          "rate": 2
        }
      ]
    },
    {
      "id": "desalinator_brine",
      "name": "Desalinator (Brine)",
      "kind": "building",
      "buildingId": "desalinator",
      "powerWatts": 480,
      "heatKdtuPerSecond": 8,
      "footprintWidth": 3,
      "footprintHeight": 3,
      "tags": [
        "liquid",
        "verified"
      ],
      "ports": [
        {
          "item": "brine",
          "direction": "input",
          "rate": 5000
        },
        {
          "item": "water",
          "direction": "output",
          "rate": 3500
        },
        {
          "item": "salt",
          "direction": "output",
          "rate": 1500
        }
      ]
    },
    {
      "id": "desalinator_salt_water",
      "name": "Desalinator (Salt Water)",
      "kind": "building",
      "buildingId": "desalinator",
      "powerWatts": 480,
      "heatKdtuPerSecond": 8,
      "footprintWidth": 3,
      "footprintHeight": 3,
      "tags": [
        "liquid",
        "verified"
      ],
      "ports": [
        {
          "item": "salt_water",
          "direction": "input",
          "rate": 5000
        },
        {
          "item": "water",
          "direction": "output",
          "rate": 4650
        },
        {
          "item": "salt",
          "direction": "output",
          "rate": 350
        }
      ]
    }
  ],
  "verifiedAgainst": "https://oxygennotincluded.wiki.gg — checked 2026-08-21"
}""";
