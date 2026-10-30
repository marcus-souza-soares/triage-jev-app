class TicketsController < ApplicationController
  def index
    @total = Ticket.count
    @page_count = Ticket.page_count
    @page = params[:page].to_i.clamp(1, @page_count)
    @tickets = Ticket.recent.page(@page)
  end

  def show
    @ticket = Ticket.find(params[:id])
  end

  def new
  end

  def create
    @body = params.require(:body)
    @strictness = params[:strictness].presence&.to_f
    @strictness = nil unless Ticket::STRICTNESS_LEVELS.include?(@strictness)

    ticket = Ticket.triage!(@body, confidence_threshold: @strictness)

    redirect_to ticket
  rescue Jevalyn::Error => e
    Rails.logger.warn("SupportTriage failed: #{e.class}: #{e.message}")
    flash.now[:alert] = "Não foi possível acessar o modelo de triagem. Tente novamente em instantes."
    render :new, status: :service_unavailable
  end
end
