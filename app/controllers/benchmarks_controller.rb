class BenchmarksController < ApplicationController
  def index
    @run = BenchmarkRun.recent.first
    @previous_runs = BenchmarkRun.recent.where.not(id: @run&.id).limit(10)
    render :show if @run
  end

  def show
    @run = BenchmarkRun.find(params[:id])
    @previous_runs = BenchmarkRun.recent.where.not(id: @run.id).limit(10)
  end
end
