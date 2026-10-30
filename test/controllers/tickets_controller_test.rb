require "test_helper"
require "jevalyn/testing/minitest"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  include Jevalyn::Testing::Minitest

  test "should list previous tickets, newest first" do
    tickets(:checkout_down).update!(created_at: 1.day.ago)

    get tickets_url

    assert_response :success
    ids = css_select("[data-ticket-id]").map { |link| link["data-ticket-id"].to_i }
    assert_equal [ tickets(:double_charge).id, tickets(:checkout_down).id ], ids
  end

  test "should paginate previous tickets" do
    base = { department: "billing", severity: "minor", urgent: false, certain: true }
    Ticket.insert_all(Array.new(Ticket::PER_PAGE) { |i| base.merge(body: "Chamado #{i}", created_at: i.minutes.from_now, updated_at: Time.current) })
    newest = Ticket.recent.first

    get tickets_url
    assert_select "[data-ticket-id]", Ticket::PER_PAGE
    assert_select "[data-ticket-id='#{newest.id}']"
    assert_select "a[rel=next]"
    assert_select "a[rel=prev]", 0

    get tickets_url(page: 2)
    assert_select "[data-ticket-id]", 2
    assert_select "[data-page='2']", /Página 2 de 2/
    assert_select "a[rel=prev]"
    assert_select "a[rel=next]", 0
  end

  test "should clamp an out-of-range page" do
    get tickets_url(page: 99)
    assert_response :success
    assert_select "[data-ticket-id]", 2

    get tickets_url(page: "abc")
    assert_response :success
    assert_select "[data-ticket-id]", 2
  end

  test "should show a ticket" do
    get ticket_url(tickets(:checkout_down))

    assert_response :success
    assert_select "[data-field=department]", "Suporte técnico"
    assert_select "[data-field=urgent]", /Sim/
    assert_select "[data-field=severity]", /Crítica/
    assert_select "[data-question=department] li", 3
    assert_select "[data-question=department] li:first-child", /Suporte técnico\s+92%/
    assert_select "[data-question=urgent]", /Margem\s+\+19 p\.p\./
    assert_select "pre", /jev-1.13-free/
  end

  test "should show a ticket triaged before the analysis was stored" do
    get ticket_url(tickets(:double_charge))

    assert_response :success
    assert_select "[data-question]", 0
    assert_select "p", /Respondido por jev-1.13-free/
  end

  test "should get new" do
    get new_ticket_url
    assert_response :success
  end

  test "should triage and save a ticket" do
    stub_jevalyn(SupportTriage, department: :technical, urgent: true, severity: "major")

    assert_difference "Ticket.count", 1 do
      post tickets_url, params: { body: "Checkout is down for every customer" }
    end

    ticket = Ticket.last
    assert_redirected_to ticket_url(ticket)
    assert_evaluated SupportTriage, times: 1
    assert_equal "technical", ticket.department
    assert ticket.urgent?
    assert_equal "major", ticket.severity
    assert_equal "Checkout is down for every customer", ticket.body
    assert_equal %w[department severity urgent], ticket.analysis_questions.keys.sort
    assert_equal 0.8, ticket.analysis_questions.dig("department", "threshold")
  end

  test "should apply the chosen strictness to every question" do
    stub_jevalyn(SupportTriage, department: :technical, urgent: true, severity: "major", confidence: 0.92)

    post tickets_url, params: { body: "Checkout is down", strictness: "0.95" }

    ticket = Ticket.last
    assert_equal 0.95, ticket.analysis["confidence_threshold"]
    assert_not ticket.certain?
    assert_includes ticket.analysis["uncertain_questions"], "department"
  end

  test "should ignore a strictness that is not offered" do
    stub_jevalyn(SupportTriage, department: :technical, urgent: true, severity: "major")

    post tickets_url, params: { body: "Checkout is down", strictness: "0.1" }

    assert_nil Ticket.last.analysis["confidence_threshold"]
  end

  test "should reject a ticket without a body" do
    assert_no_difference "Ticket.count" do
      post tickets_url
    end

    assert_response :bad_request
    refute_evaluated SupportTriage
  end

  test "should show an error when Jev is unreachable" do
    stub_jevalyn(SupportTriage) { raise Jevalyn::ConnectionError, "down" }

    assert_no_difference "Ticket.count" do
      post tickets_url, params: { body: "Checkout is down" }
    end

    assert_response :service_unavailable
    assert_select "[role=alert]", /Não foi possível acessar/
  end
end
