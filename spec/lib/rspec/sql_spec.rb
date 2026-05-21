# frozen_string_literal: true

require "rspec/sql"
require_relative "../../support/database"

RSpec.describe RSpec::Sql do
  include RSpec::Sql

  it "expects database queries" do
    expect { User.last }.to query_database
  end

  it "raises without database queries" do
    expect {
      expect { nil }.to query_database
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
  end

  it "expects no database queries" do
    expect { nil }.to_not query_database
  end

  it "expects no database queries" do
    expect { nil }.to query_database 0

    expect {
      expect { nil }.to query_database 1
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
  end

  it "expects a number of database queries" do
    expect { User.last }.to query_database 1
    expect { User.create! }.to query_database 3.times

    expect {
      expect { User.last }.to query_database 2
    }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
  end

  it "shows which queries were executed" do
    expect {
      expect { User.connection.execute("SELECT 1") }.to query_database []
    }.to raise_error match("SELECT 1")
  end

  it "expects certain queries" do
    expect { User.last }.to query_database ["User Load"]
  end

  it "expects multiple queries" do
    expect { User.create!.update(name: "Jane") }.to query_database [
      "TRANSACTION",
      "User Create",
      "TRANSACTION",
      "TRANSACTION",
      "User Update",
      "TRANSACTION",
    ]
  end

  it "expects a summary of queries" do
    expect { User.create!.update(name: "Jane") }.to query_database(
      {
        insert: { users: 1 },
        update: { users: 1 },
      }
    )
  end

  it "prints user-friendly message expecting nothing" do
    message = error_message { expect { User.last }.not_to query_database }
    expect(message).to eq <<~TXT
      Expected no database queries but observed:

      User Load  SELECT "users".* FROM "users" ORDER BY "users"."id" DESC LIMIT ?
    TXT
  end

  it "prints user-friendly message expecting something" do
    message = error_message { expect { nil }.to query_database }
    expect(message).to eq(
      "Expected at least one database query but observed none."
    )
  end

  it "prints user-friendly message expecting a number" do
    message = error_message { expect { User.last }.to query_database 0 }
    expect(message).to eq <<~TXT
      Expected database queries: 0
      Actual database queries:   1

      Diff: +1

      Full query log:

      User Load  SELECT "users".* FROM "users" ORDER BY "users"."id" DESC LIMIT ?
    TXT
  end

  it "prints user-friendly message expecting x.times" do
    message = error_message { expect { User.last }.to query_database 2.times }
    expect(message).to eq <<~TXT
      Expected database queries: 2
      Actual database queries:   1

      Diff: -1

      Full query log:

      User Load  SELECT "users".* FROM "users" ORDER BY "users"."id" DESC LIMIT ?
    TXT
  end

  it "prints user-friendly message expecting list" do
    message = error_message do
      expect { User.last }.to query_database ["User Update"]
    end

    expect(message).to eq <<~TXT
      Expected database queries: ["User Update"]
      Actual database queries:   ["User Load"]

      Diff:
      @@ -1 +1 @@
      -["User Update"]
      +["User Load"]


      Full query log:

      User Load  SELECT "users".* FROM "users" ORDER BY "users"."id" DESC LIMIT ?
    TXT
  end

  it "prints user-friendly message expecting summary" do
    skip "testing old ruby" unless RUBY_VERSION < "3.4"

    message = error_message do
      expect { User.last }.to query_database(
        update: { user: 1 }
      )
    end

    # This message could be better but nobody has asked for it yet.
    expect(message).to eq <<~TXT
      Expected database queries: {:update=>{:user=>1}}
      Actual database queries:   {:select=>{:users=>1}}

      Diff:
      @@ -1 +1 @@
      -:update => {:user=>1},
      +:select => {:users=>1},


      Full query log:

      User Load  SELECT "users".* FROM "users" ORDER BY "users"."id" DESC LIMIT ?
    TXT
  end

  it "prints user-friendly message expecting summary" do
    skip "testing new ruby" if RUBY_VERSION < "3.4"

    message = error_message do
      expect { User.last }.to query_database(
        update: { user: 1 }
      )
    end

    expect(message).to eq <<~TXT
      Expected database queries: {update: {user: 1}}
      Actual database queries:   {select: {users: 1}}

      Diff:
      @@ -1 +1 @@
      -:update => {user: 1},
      +:select => {users: 1},


      Full query log:

      User Load  SELECT "users".* FROM "users" ORDER BY "users"."id" DESC LIMIT ?
    TXT
  end

  def error_message
    yield
  rescue RSpec::Expectations::ExpectationNotMetError => e
    # Remove colours and trailing whitespace from message:
    e.message.gsub(/\e\[(\d+)m/, "").gsub(/ $/, "")
  end
end
