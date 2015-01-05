class HomeController < ApplicationController
  skip_before_action :ensure_login, only: [:login, :privacy]

  def index
    @page_title = _('Dashboard')
  end

  def connect
    redirect_to '/#dash-connect' && return unless request.xhr?
  end

  def cultivate
    redirect_to '/#dash-cultivate' && return unless request.xhr?
  end

  def care
    redirect_to '/#dash-care' && return unless request.xhr?
  end

  def progress
    redirect_to '/#dash-progress' && return unless request.xhr?

    if params[:start_date]
      @start_date = Date.parse(params[:start_date])
    else
      @start_date = Date.today.beginning_of_week
    end
    @end_date = @start_date.end_of_week

    all_tasks = current_account_list.tasks.completed_between(@start_date, @end_date)

    @counts = {
      phone: {
        completed: all_tasks.of_type('Call')
                            .with_result(%w(Completed Done))
                            .count,
        attempted: all_tasks.of_type('Call')
                            .with_result(['Attempted - Left Message', 'Attempted'])
                            .count,
        received: all_tasks.of_type('Call')
                           .with_result('Received')
                           .count,
        appointments: all_tasks.of_type('Call')
                               .where(next_action: 'Appointment Scheduled')
                               .count
      },
      email: {
        sent: all_tasks.of_type('Email')
                       .with_result(%w(Completed Done))
                       .count,
        received: all_tasks.of_type('Email')
                           .with_result('Received')
                           .count
      },
      facebook: {
        sent: all_tasks.of_type('Facebook Message')
                       .with_result(%w(Completed Done))
                       .count,
        received: all_tasks.of_type('Facebook Message')
                           .with_result('Received')
                           .count
      },
      text_message: {
        sent: all_tasks.of_type('Text Message')
                       .with_result(%w(Completed Done))
                       .count,
        received: all_tasks.of_type('Text Message')
                           .with_result('Received')
                           .count
      },
      electronic: {
        sent: 0,
        received: 0,
        appointments: all_tasks.of_type(['Email', 'Facebook Message', 'Text Message'])
                               .where(next_action: 'Appointment Scheduled')
                               .count
      },
      appointments: {
        completed: all_tasks.of_type('Appointment')
                            .with_result(%w(Completed Done))
                            .count
      },
      correspondence: {
        precall: all_tasks.of_type('Pre Call Letter')
                          .with_result('Done')
                          .count,
        support_letters: all_tasks.of_type('Support Letter')
                                  .with_result('Done')
                                  .count,
        thank_yous: all_tasks.of_type('Thank')
                             .with_result('Done')
                             .count,
        reminders: all_tasks.of_type('Reminder Letter')
                            .with_result('Done')
                            .count
      },
      contacts: {
        active: current_account_list.contacts
                                    .where(status: ['Never Contacted', 'Contact for Appointment', '', nil])
                                    .count,
        referrals: current_account_list.contacts
                                       .created_between(@start_date, @end_date)
                                       .joins(:contact_referrals_to_me).uniq
                                       .count
      }
    }
    @counts[:electronic][:sent] = @counts[:email][:sent] +
                                  @counts[:facebook][:sent] +
                                  @counts[:text_message][:sent]
    @counts[:electronic][:received] = @counts[:email][:received] +
                                  @counts[:facebook][:received] +
                                  @counts[:text_message][:received]
  end

  def login
    render layout: false
  end

  def privacy
    render layout: false
  end

  def change_account_list
    session[:current_account_list_id] = params[:id] if current_user.account_lists.pluck('account_lists.id').include?(params[:id].to_i)
    redirect_to '/'
  end

  def download_data_check
    render text: current_user.organization_accounts.any?(&:downloading?)
  end
end
