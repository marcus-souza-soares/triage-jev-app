require "test_helper"

class BenchmarksControllerTest < ActionDispatch::IntegrationTest
  test "should show the latest run" do
    newer = BenchmarkRun.create!(benchmark_runs(:first).attributes.except("id", "created_at", "updated_at"))

    get benchmarks_url

    assert_response :success
    assert_select "[data-metric=avg_wall_ms]", /400 ms.*6,00 s.*15,0×/m
    assert_select "[data-metric=avg_net_input_tokens]", /350/
    assert_select "a[href=?]", benchmark_path(benchmark_runs(:first))
    assert_select "a[href=?]", benchmark_path(newer), 0
  end

  test "should show a run" do
    get benchmark_url(benchmark_runs(:first))

    assert_response :success
    assert_select "td", /Crítica/
    assert_select "td span.line-through", "Alta"
  end

  test "should leave out the opencode overhead for a direct API run" do
    run = benchmark_runs(:first)
    run.update!(llm_model: "openai/gpt-5", summary: run.summary.merge("baseline" => nil, "llm_options" => { "reasoning_effort" => "minimal" }))

    get benchmark_url(run)

    assert_response :success
    assert_select "h2", text: "Custo fixo do opencode", count: 0
    assert_select "p", /openai\/gpt-5 \(raciocínio minimal\)/
  end

  test "should explain how to run one when there are none" do
    BenchmarkRun.delete_all

    get benchmarks_url

    assert_response :success
    assert_select "code", /benchmark:triage/
  end
end
