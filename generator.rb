#!/usr/bin/env ruby

# Copyright 2019 University of California, Riverside
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Base class for the generator
class Generator
  # Initialize the random number generator and the two common parameters
  def initialize(card, d = 2)
    @random = Random.new
    @card = card
    @d = d
  end

  # Generates a random value in the range [0, 1)
  def rnd
    @random.rand
  end

  # Generates either 0 or 1 from a Bernoulli distribution with parameter p
  def bernoulli(p)
    rnd <= p ? 1 : 0
  end

  # Generates a number from a uniform distribution U(a, b)
  def uniform(a, b)
    (b - a) * rnd + a
  end

  # Generates a number from the normal (Gaussian) distribution with mean mu and standard deviation sigma
  def normal(mu, sigma)
    mu + sigma * Math::sqrt(-2 * Math::log(rnd))*Math::sin(2 * Math::PI * rnd)
  end
end

# Abstract class for the point generators (the first five generators)
class PointGenerator < Generator

  # Initialize one of the first five generators that are based on points
  # In addition to the two common parameters, the first two specific parameters are always maxWidth and maxHeight for generating rectangles
  def initialize(card, d, maxWidth, maxHeight)
    super(card, d)
    @maxWidth = maxWidth
    @maxHeight = maxHeight
  end

  # Generates all the rectangles by first generating points and then generating rectangles around these points
  def generate
    g = []
    i = 0
    prevPoint = nil
    while (i < @card)
      # Call the abstract generatePoint function
      x, y = generatePoint(prevPoint, i)
      if (pointInSpace(x, y))
        prevPoint = [x, y]
        w = uniform(0, @maxWidth)
        h = uniform(0, @maxHeight)
        g << [x - w / 2, y - h / 2, w, h]
        i += 1
      end
    end
    g
  end

  def pointInSpace(x, y)
    x >= 0.0 && x <= 1.0 && y >= 0.0 && y <= 1.0
  end
end

# Generates points from the uniform distribution in the space [(0,0), (1,1)]
class UniformGenerator < PointGenerator
  def generatePoint(prevPoint, i)
    [rnd, rnd]
  end
end

# Generates points from the diagonal distribution
class DiagonalGenerator < PointGenerator
  def initialize(card, d, maxWidth, maxHeight, percentage, buffer)
    super(card, d, maxWidth, maxHeight)
    @percentage = percentage
    @buffer = buffer
  end

  # Generate a point from a diagonal distribution
  def generatePoint(prevPoint, i)
    if (bernoulli(@percentage) == 1)
      # Generate a point exactly on the diagonal
      x = y = uniform(0, 1)
    else
      # Deviate a little bit from the diagonal
      c = uniform(0, 1)
      d = normal(0, @buffer / 5)
      x = c + d / Math::sqrt(2)
      y = c - d / Math::sqrt(2)
    end
    return x, y
  end
end

# Generates points from the Gaussian distribution
class GaussianGenerator < PointGenerator
  # Generate a point from the Gaussian distribution
  def generatePoint(prevPoint, i)
    x = normal(0.5, 0.1)
    y = normal(0.5, 0.1)
    return x, y
  end
end

# Generates points from the Sierpinsky distribution
class SierpinskyGenerator < PointGenerator
  # Generate a point using the Sierpinsky's triangle
  def generatePoint(prevPoint, i)
    case i
    when 0
      [0.0, 0.0]
    when 1
      [1.0, 0.0]
    when 2
      [0.5, Math::sqrt(3) / 2]
    else
      case dice(5)
      when 1..2
        middlePoint(prevPoint, [0.0, 0.0])
      when 3..4
        middlePoint(prevPoint, [1.0, 0.0])
      when 5
        middlePoint(prevPoint, [0.5, Math::sqrt(3) / 2])
      end
    end
  end

  # Generates a random integer number in the range [1, n]
  def dice(n)
    (rnd * n).floor + 1
  end

  # Computes the middle point between two points
  def middlePoint(point1, point2)
    [(point1[0] + point2[0]) / 2.0, (point1[1] + point2[1]) / 2.0]
  end
end

# Generates points from the bit distribution
class BitGenerator < PointGenerator
  def initialize(card, d, maxWidth, maxHeight, p, digits)
    super(card, d, maxWidth, maxHeight)
    @p = p
    @digits = digits.to_i
  end

  def generatePoint(prevPoint, i)
    [generateBit, generateBit]
  end

  def generateBit
    n = 0
    i = 1
    @digits.times do
      c = bernoulli(@p)
      n += c * 1.0 / (1 << i)
      i += 1
    end
    n
  end
end

class ParcelGenerator < Generator
  def initialize(card, d, r, alpha)
    super(card, d)
    @r = r
    @alpha = alpha
  end

  def generate
    # Initial box
    box = [0.0, 0.0, 1.0, 1.0]
    g = [box]
    # Generate the initial parcels by splitting the box @card - 1 times
    while g.length < @card
      box = g.slice!(0)
      # if box width > box height
      if (box[2] > box[3])
        split_size = box[2] * uniform(@r, 1-@r)
        box1 = [box[0], box[1], split_size, box[3]]
        box2 = [box[0] + split_size, box[1], box[2] - split_size, box[3]]
      else
        split_size = box[3] * uniform(@r, 1-@r)
        box1 = [box[0], box[1], box[2], split_size]
        box2 = [box[0], box[1] + split_size, box[2], box[3] - split_size]
      end
      g << box1
      g << box2
    end

    # Add noise using dithering
    g.map do |box|
      [box[0], box[1], box[2] * (1-uniform(0, @alpha)), box[3] * (1- uniform(0, @alpha))]
    end
  end
end

if __FILE__ == $0
  if (ARGV.length < 5)
    $stderr.puts "Usage: #{__FILE__} <distribution> <cardinality> <dimensions> [distribution specific parameters]"
    $stderr.puts "The available distributions are: {uniform, diagonal, gaussian, sierpinsky, bit, parcel}"
    $stderr.puts "cardinality: The number of records to generate"
    $stderr.puts "dimensions: The dimensionality of the generated geometries. Currently, on two-dimensional data is supported."
    $stderr.puts "Refer to the gem description for the model specific parmaeters"
    exit 1
  end
  # Command line interface (CLI)
  generatorType = ARGV.slice!(0)
  # Convert all remaining parameters to floating point
  ARGV.map!(&:to_f)
  generator = case generatorType
  when "uniform"
    UniformGenerator.new(*ARGV.slice!(0..3))
  when "diagonal"
    DiagonalGenerator.new(*ARGV.slice!(0..5))
  when "gaussian"
    GaussianGenerator.new(*ARGV.slice!(0..3))
  when "sierpinsky"
    SierpinskyGenerator.new(*ARGV.slice!(0..3))
  when "bit"
    BitGenerator.new(*ARGV.slice!(0..5))
  when "parcel"
    ParcelGenerator.new(*ARGV.slice!(0..5))
  end

  geometries = generator.generate
  for geometry in geometries
    x1, y1, x2, y2 = geometry[0], geometry[1], geometry[0] + geometry[2], geometry[1] + geometry[3]
    puts ("POLYGON ((%f %f, %f %f, %f %f, %f %f, %f %f))" % [
      x1, y1, x2, y1, x2, y2, x1, y2, x1, y1
    ])
  end
end
