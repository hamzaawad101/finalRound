extends Node

var playerBody: CharacterBody2D
var game_started = false
var playerDamageZone: Area2D

var playerDamageAmount: int
var playerAlive: bool

var AiDamageZone: Area2D
var AiDamageAmount: int

var selected_ai_character = "computer" # default
