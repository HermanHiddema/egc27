class EgdGradeMapping
  MIN_KYU = 30
  MAX_DAN = 9
  MAX_PRO = 9
  MIN_GRADE_N = 0
  MAX_GRADE_N = 29 + MAX_DAN + MAX_PRO

  class << self
    def options_for_select
      pro_options.reverse + dan_options.reverse + kyu_options.reverse
    end

    def grade_for(grade_n)
      value = safe_integer(grade_n)
      return nil if value.nil?
      return nil if value < MIN_GRADE_N || value > MAX_GRADE_N

      return "#{MIN_KYU - value} kyu" if value <= 29
      return "#{value - 29} dan" if value <= 29 + MAX_DAN

      "#{value - 29 - MAX_DAN} dan pro"
    end

    def grade_n_for(value)
      return nil if value.blank?

      integer = safe_integer(value)
      return integer unless integer.nil?

      normalized = value.to_s.strip.downcase
      return nil if normalized.blank?

      if (match = normalized.match(/\A(\d{1,2})\s*(k|kyu)\z/))
        kyu = match[1].to_i
        return nil if kyu < 1 || kyu > MIN_KYU

        return MIN_KYU - kyu
      end

      if (match = normalized.match(/\A(\d{1,2})\s*(d|dan)\z/))
        dan = match[1].to_i
        return nil if dan < 1 || dan > MAX_DAN

        return 29 + dan
      end

      if (match = normalized.match(/\A(\d{1,2})\s*(p|pro\s*dan|dan\s*pro)\z/))
        pro = match[1].to_i
        return nil if pro < 1 || pro > MAX_PRO

        return 29 + MAX_DAN + pro
      end

      nil
    end

    private

    def safe_integer(value)
      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end

    def kyu_options
      MIN_KYU.downto(1).map do |kyu|
        ["#{kyu} kyu", MIN_KYU - kyu]
      end
    end

    def dan_options
      (1..MAX_DAN).map do |dan|
        ["#{dan} dan", 29 + dan]
      end
    end

    def pro_options
      (1..MAX_PRO).map do |pro|
        ["#{pro} dan pro", 29 + MAX_DAN + pro]
      end
    end
  end
end
