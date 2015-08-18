# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150624181202) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "menus", force: true do |t|
    t.integer "menu_id"
    t.string  "texto",      limit: 250
    t.string  "textoayuda", limit: 250
    t.string  "iconopen",   limit: 100
    t.string  "iconclosed", limit: 100
    t.string  "metodo",     limit: 100
  end

  add_index "menus", ["texto"], name: "menus_texto_key", unique: true, using: :btree

  create_table "propiedad", force: true do |t|
    t.string   "codpropiedad"
    t.text     "tcorto"
    t.text     "tlargo"
    t.text     "tcomercial"
    t.integer  "componertcorto_id"
    t.integer  "componertlargo_id"
    t.integer  "componertcomercial_id"
    t.boolean  "propnumerica"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "propiedades", force: true do |t|
    t.string  "codpropiedad",          limit: 5,   default: "",    null: false
    t.string  "tcorto",                limit: 60
    t.string  "tlargo",                limit: 100
    t.string  "tcomercial",            limit: 100
    t.boolean "propnumerica",                      default: false
    t.integer "componertcorto_id",                 default: 1
    t.integer "componertlargo_id",                 default: 1
    t.integer "componertcomercial_id",             default: 1
  end

  create_table "propiedades_componer", force: true do |t|
    t.string "describe", limit: 25
  end

end
