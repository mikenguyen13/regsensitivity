# DMP bounds at BFG2020 cbar=0.1 are stable across upgrades

    {
      "type": "double",
      "attributes": {
        "dim": {
          "type": "integer",
          "attributes": {},
          "value": [11, 5]
        },
        "dimnames": {
          "type": "list",
          "attributes": {},
          "value": [
            {
              "type": "NULL"
            },
            {
              "type": "character",
              "attributes": {},
              "value": ["rxbar", "rybar", "cbar", "bmin", "bmax"]
            }
          ]
        }
      },
      "value": [0, 0.2, 0.4, 0.6, 0.8, 1, 1.2, 1.4, 1.6, 1.8, 2, "Inf", "Inf", "Inf", "Inf", "Inf", "Inf", "Inf", "Inf", "Inf", "Inf", "Inf", 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 2.05476, 1.7517, 1.43515, 1.10318, 0.7535, 0.38334, -0.01072, -0.43297, -0.88882, -1.38526, -1.93153, 2.05476, 2.35782, 2.67437, 3.00634, 3.35601, 3.72617, 4.12024, 4.54249, 4.99834, 5.49478, 6.04105]
    }

# DMP breakdown at BFG2020 over cbar grid is stable

    {
      "type": "double",
      "attributes": {
        "dim": {
          "type": "integer",
          "attributes": {},
          "value": [11, 2]
        },
        "dimnames": {
          "type": "list",
          "attributes": {},
          "value": [
            {
              "type": "NULL"
            },
            {
              "type": "character",
              "attributes": {},
              "value": ["index", "breakdown"]
            }
          ]
        }
      },
      "value": [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.35003, 1.19473, 1.0802, 0.99344, 0.92688, 0.87605, 0.83852, 0.81368, 0.80358, 0.80356, 0.80356]
    }

# Oster equality bounds at BFG2020 are stable

    {
      "type": "double",
      "attributes": {
        "dim": {
          "type": "integer",
          "attributes": {},
          "value": [11, 5]
        },
        "dimnames": {
          "type": "list",
          "attributes": {},
          "value": [
            {
              "type": "NULL"
            },
            {
              "type": "character",
              "attributes": {},
              "value": ["delta", "r2long", "beta1", "beta2", "beta3"]
            }
          ]
        }
      },
      "value": [-1, -0.8, -0.6, -0.4, -0.2, 0, 0.2, 0.4, 0.6, 0.8, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.69842, 0.93048, 1.18007, 1.44903, 1.73964, 2.05476, 2.39811, 2.77473, 3.19169, 3.65945, -46.17075, "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", 4.19438, "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA", "NA"]
    }

# Oster sign-change breakdown across r2long grid is stable

    {
      "type": "double",
      "attributes": {
        "dim": {
          "type": "integer",
          "attributes": {},
          "value": [18, 2]
        },
        "dimnames": {
          "type": "list",
          "attributes": {},
          "value": [
            {
              "type": "NULL"
            },
            {
              "type": "character",
              "attributes": {},
              "value": ["index", "breakdown"]
            }
          ]
        }
      },
      "value": [0.15, 0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1, 0.97383, 0.97344, 0.97304, 0.97263, 0.97221, 0.97178, 0.97133, 0.97087, 0.9704, 0.96991, 0.96941, 0.96889, 0.96836, 0.96781, 0.96724, 0.96666, 0.96605, 0.96543]
    }

# DGP summary statistics are stable

    {
      "type": "list",
      "attributes": {
        "names": {
          "type": "character",
          "attributes": {},
          "value": ["beta_short", "beta_med", "r_short", "r_med", "k0", "k1", "k2", "n", "n_compare"]
        }
      },
      "value": [
        {
          "type": "double",
          "attributes": {},
          "value": [1.924555]
        },
        {
          "type": "double",
          "attributes": {},
          "value": [2.054759]
        },
        {
          "type": "double",
          "attributes": {},
          "value": [0.032815]
        },
        {
          "type": "double",
          "attributes": {},
          "value": [0.105128]
        },
        {
          "type": "double",
          "attributes": {},
          "value": [0.882336]
        },
        {
          "type": "double",
          "attributes": {},
          "value": [1.812988]
        },
        {
          "type": "double",
          "attributes": {},
          "value": [94.76834]
        },
        {
          "type": "integer",
          "attributes": {},
          "value": [2036]
        },
        {
          "type": "integer",
          "attributes": {},
          "value": [10]
        }
      ]
    }

