module PayslipGenerator
  extend ActiveSupport::Concern

  def pdf_generator(payslip, download = nil)
    payslips = []
    payslips.push(payslip.id)

    pdf_generate_multi(payslips, download)
  end

  def pdf_generate_multi(payslips, download = nil)
    pdf = PayslipPdf.new(payslips)

    pdf.generate()
    file_name = "payslips-#{Time.now.to_i}.pdf"

    data = pdf.render()

    if download
      send_data(data, disposition: 'attachment', filename: file_name, type: "application/pdf")
    else
      send_data(data, disposition: 'inline', filename: file_name, type: "application/pdf")
    end
  end

end
