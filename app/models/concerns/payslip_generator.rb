module PayslipGenerator
  extend ActiveSupport::Concern

  def voucher_generator(vacation, download = nil)
    pdf = VoucherPdf.new(vacation)
    pdf.generate()

    filename = "voucher-#{Time.now.to_i}.pdf"

    output_pdf(pdf, filename, download)
  end

  def pdf_generator(payslip, download = nil)
    payslips = []
    payslips.push(payslip.id)

    pdf_generate_multi(payslips, download)
  end

  def pdf_generate_multi(payslips, download = nil)
    pdf = PayslipPdf.new(payslips)
    pdf.generate()

    filename = "payslips-#{Time.now.to_i}.pdf"

    output_pdf(pdf, filename, download)
  end

  private

  def output_pdf(pdf, filename, download)
    data = pdf.render()

    if download
      send_data(data, disposition: 'attachment', filename: filename, type: "application/pdf")
    else
      send_data(data, disposition: 'inline', filename: filename, type: "application/pdf")
    end
  end

end
